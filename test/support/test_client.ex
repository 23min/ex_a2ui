defmodule A2UI.TestClient do
  @moduledoc "Minimal WebSocket test client for A2UI. Requires :gun."

  @typedoc "A test WebSocket client handle (pid of buffer process)."
  @type client :: pid()

  @doc """
  Opens a WebSocket connection to the given URL for testing.

  Returns `{:ok, client}` on success, `{:error, reason}` on failure.
  Requires the `:gun` application to be started.

  The returned client is a buffer process PID. The buffer process owns the
  gun connection, so all gun messages flow directly to it.
  """
  @spec connect(String.t()) :: {:ok, client()} | {:error, term()}
  def connect(url) do
    caller = self()
    ref = make_ref()

    # Spawn the buffer process; it will open the gun connection so it receives
    # all gun messages directly. Connection result is sent back to caller.
    client =
      spawn(fn ->
        uri = URI.parse(url)
        host = String.to_charlist(uri.host || "localhost")
        port = uri.port || 4001
        path = if uri.query, do: "#{uri.path}?#{uri.query}", else: uri.path || "/ws"

        result =
          case :gun.open(host, port) do
            {:ok, conn_pid} ->
              case :gun.await_up(conn_pid, 5000) do
                {:ok, _protocol} ->
                  stream_ref = :gun.ws_upgrade(conn_pid, String.to_charlist(path))

                  receive do
                    {:gun_upgrade, ^conn_pid, ^stream_ref, [<<"websocket">>], _headers} ->
                      {:ok, conn_pid, stream_ref}

                    {:gun_response, ^conn_pid, ^stream_ref, _, status, _headers} ->
                      :gun.close(conn_pid)
                      {:error, {:upgrade_failed, status}}
                  after
                    5000 ->
                      :gun.close(conn_pid)
                      {:error, :upgrade_timeout}
                  end

                {:error, reason} ->
                  :gun.close(conn_pid)
                  {:error, {:connect_failed, reason}}
              end

            {:error, reason} ->
              {:error, {:open_failed, reason}}
          end

        case result do
          {:ok, conn_pid, stream_ref} ->
            send(caller, {:connect_result, ref, :ok})
            buffer_loop(conn_pid, stream_ref, [])

          {:error, reason} ->
            send(caller, {:connect_result, ref, {:error, reason}})
        end
      end)

    receive do
      {:connect_result, ^ref, :ok} -> {:ok, client}
      {:connect_result, ^ref, {:error, reason}} -> {:error, reason}
    after
      10_000 -> {:error, :connect_timeout}
    end
  end

  # Buffer process: receives raw frames from gun, decodes each JSON array
  # into individual tagged messages, queues them for pop requests.
  # When queue is empty and a pop request arrives, waits for next gun frame.
  # Queue entries: {raw_frame_binary, decoded_msg_map}
  defp buffer_loop(conn_pid, stream_ref, queue) do
    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, {:text, data}} ->
        new_entries = decode_frame_to_entries(data)
        buffer_loop(conn_pid, stream_ref, queue ++ new_entries)

      {:gun_down, ^conn_pid, _, _, _} ->
        buffer_loop(conn_pid, stream_ref, queue)

      {:gun_ws, ^conn_pid, ^stream_ref, _} ->
        buffer_loop(conn_pid, stream_ref, queue)

      {:pop, ref, caller_pid, mode} ->
        case queue do
          [] ->
            buffer_wait_for(conn_pid, stream_ref, ref, caller_pid, mode)

          [{raw, msg} | rest] ->
            send_reply(caller_pid, ref, mode, raw, msg)
            buffer_loop(conn_pid, stream_ref, rest)
        end

      {:send_ws, data} ->
        :gun.ws_send(conn_pid, stream_ref, {:text, data})
        buffer_loop(conn_pid, stream_ref, queue)

      :disconnect ->
        :gun.close(conn_pid)
    end
  end

  defp buffer_wait_for(conn_pid, stream_ref, ref, caller_pid, mode) do
    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, {:text, data}} ->
        new_entries = decode_frame_to_entries(data)

        case new_entries do
          [] ->
            buffer_wait_for(conn_pid, stream_ref, ref, caller_pid, mode)

          [{raw, msg} | rest] ->
            send_reply(caller_pid, ref, mode, raw, msg)
            buffer_loop(conn_pid, stream_ref, rest)
        end

      {:gun_down, ^conn_pid, _, _, _} ->
        send(caller_pid, {:buffer_empty, ref})
        buffer_loop(conn_pid, stream_ref, [])

      {:gun_ws, ^conn_pid, ^stream_ref, _} ->
        buffer_wait_for(conn_pid, stream_ref, ref, caller_pid, mode)

      {:send_ws, data} ->
        :gun.ws_send(conn_pid, stream_ref, {:text, data})
        buffer_wait_for(conn_pid, stream_ref, ref, caller_pid, mode)

      :disconnect ->
        send(caller_pid, {:buffer_empty, ref})
        :gun.close(conn_pid)

      {:pop, new_ref, new_caller, new_mode} ->
        # Another pop arrived while waiting; accumulate and handle when frame arrives.
        buffer_wait_for_with_pending(
          conn_pid,
          stream_ref,
          ref,
          caller_pid,
          mode,
          [{new_ref, new_caller, new_mode}]
        )
    after
      65_000 ->
        send(caller_pid, {:buffer_empty, ref})
        buffer_loop(conn_pid, stream_ref, [])
    end
  end

  defp buffer_wait_for_with_pending(conn_pid, stream_ref, ref, caller_pid, mode, pending) do
    all_waiting = [{ref, caller_pid, mode} | pending]

    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, {:text, data}} ->
        new_entries = decode_frame_to_entries(data)
        {to_deliver, leftover_entries} = Enum.split(new_entries, length(all_waiting))

        Enum.zip(all_waiting, to_deliver)
        |> Enum.each(fn {{r, c, m}, {raw, msg}} ->
          send_reply(c, r, m, raw, msg)
        end)

        remaining_waiting = Enum.drop(all_waiting, length(to_deliver))

        case remaining_waiting do
          [] ->
            buffer_loop(conn_pid, stream_ref, leftover_entries)

          [{next_ref, next_caller, next_mode} | rest_waiting] ->
            buffer_wait_for_with_pending(
              conn_pid,
              stream_ref,
              next_ref,
              next_caller,
              next_mode,
              rest_waiting
            )
        end

      {:gun_ws, ^conn_pid, ^stream_ref, _} ->
        buffer_wait_for_with_pending(conn_pid, stream_ref, ref, caller_pid, mode, pending)

      {:gun_down, ^conn_pid, _, _, _} ->
        for {r, c, _} <- all_waiting, do: send(c, {:buffer_empty, r})
        buffer_loop(conn_pid, stream_ref, [])

      {:send_ws, data} ->
        :gun.ws_send(conn_pid, stream_ref, {:text, data})
        buffer_wait_for_with_pending(conn_pid, stream_ref, ref, caller_pid, mode, pending)

      {:pop, new_ref, new_caller, new_mode} ->
        buffer_wait_for_with_pending(
          conn_pid,
          stream_ref,
          ref,
          caller_pid,
          mode,
          pending ++ [{new_ref, new_caller, new_mode}]
        )

      :disconnect ->
        for {r, c, _} <- all_waiting, do: send(c, {:buffer_empty, r})
        :gun.close(conn_pid)
    after
      65_000 ->
        for {r, c, _} <- all_waiting, do: send(c, {:buffer_empty, r})
        buffer_loop(conn_pid, stream_ref, [])
    end
  end

  defp send_reply(caller_pid, ref, :msg, _raw, msg),
    do: send(caller_pid, {:buffer_msg, ref, msg})

  defp send_reply(caller_pid, ref, :raw, raw, _msg),
    do: send(caller_pid, {:buffer_raw, ref, raw})

  # Decodes a raw JSON frame into a list of {raw_binary, tagged_map} pairs.
  # Each A2UI message array may contain updateComponents, createSurface, etc.
  # We extract them individually into maps with "type" keys.
  # The raw_binary is the original frame data (for receive_raw callers).
  defp decode_frame_to_entries(raw_data) do
    case Jason.decode(raw_data) do
      {:ok, messages} when is_list(messages) ->
        all_components =
          Enum.flat_map(messages, fn m ->
            case m do
              %{"updateComponents" => %{"components" => comps}} -> comps
              _ -> []
            end
          end)

        Enum.flat_map(messages, fn msg ->
          cond do
            Map.has_key?(msg, "createSurface") ->
              tagged =
                Map.merge(
                  %{"type" => "createSurface", "components" => all_components},
                  msg["createSurface"] || %{}
                )

              [{raw_data, tagged}]

            Map.has_key?(msg, "updateComponents") ->
              update = msg["updateComponents"]
              comps = update["components"] || []

              tagged = %{
                "type" => "updateComponents",
                "components" => comps,
                "updates" => comps,
                "surfaceId" => update["surfaceId"]
              }

              [{raw_data, tagged}]

            true ->
              []
          end
        end)

      _ ->
        []
    end
  end

  @doc """
  Receives the next A2UI message from the WebSocket, decoded as a map.

  Each call returns one A2UI message. A single WebSocket frame may contain
  multiple messages (e.g., updateComponents + createSurface); subsequent
  calls drain them in order.

  Returns `{:ok, map}`, `{:timeout, nil}`, or `{:error, reason}`.
  """
  @spec receive(client(), non_neg_integer()) ::
          {:ok, map()} | {:timeout, nil} | {:error, term()}
  def receive(client, timeout_ms) when is_pid(client) do
    ref = make_ref()
    send(client, {:pop, ref, self(), :msg})

    receive do
      {:buffer_msg, ^ref, msg} -> {:ok, msg}
      {:buffer_empty, ^ref} -> {:timeout, nil}
    after
      timeout_ms + 200 -> {:timeout, nil}
    end
  end

  @doc """
  Returns the next raw WebSocket frame text as a binary string.
  """
  @spec receive_raw(client(), non_neg_integer()) :: binary() | nil
  def receive_raw(client, timeout_ms) when is_pid(client) do
    ref = make_ref()
    send(client, {:pop, ref, self(), :raw})

    receive do
      {:buffer_raw, ^ref, data} -> data
      {:buffer_empty, ^ref} -> nil
    after
      timeout_ms + 200 -> nil
    end
  end

  @doc """
  Sends an action to the A2UI server via WebSocket.

  Wraps `params` in the A2UI v0.9 action envelope.
  The `"action"` key in params becomes the event name.
  All other keys become the action context.
  """
  @spec send_action(client(), map()) :: :ok
  def send_action(client, params) when is_pid(client) do
    {action_name, context} = Map.pop(params, "action", "unknown")

    event =
      if map_size(context) > 0 do
        %{"name" => action_name, "context" => context}
      else
        %{"name" => action_name}
      end

    envelope =
      Jason.encode!([
        %{
          "action" => %{
            "event" => event
          }
        }
      ])

    send(client, {:send_ws, envelope})
    :ok
  end

  @doc """
  Disconnects a test WebSocket client.
  """
  @spec disconnect(client()) :: :ok
  def disconnect(client) when is_pid(client) do
    send(client, :disconnect)
    :ok
  end

end
