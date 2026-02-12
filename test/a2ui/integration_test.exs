defmodule A2UI.IntegrationTest do
  use ExUnit.Case, async: false

  defmodule CounterProvider do
    @behaviour A2UI.SurfaceProvider

    alias A2UI.Builder, as: UI

    @impl true
    def init(_opts), do: {:ok, %{count: 0}}

    @impl true
    def surface(state) do
      UI.surface("counter")
      |> UI.text("count", "#{state.count}")
      |> UI.button("inc", "+1", action: "inc")
      |> UI.card("main", children: ["count", "inc"])
      |> UI.root("main")
    end

    @impl true
    def handle_action(%A2UI.Action{name: "inc"}, state) do
      new = %{state | count: state.count + 1}
      {:reply, surface(new), new}
    end

    def handle_action(_, state), do: {:noreply, state}
  end

  defmodule PushCounterProvider do
    @behaviour A2UI.SurfaceProvider

    alias A2UI.Builder, as: UI

    @impl true
    def init(_opts), do: {:ok, %{count: 0}}

    @impl true
    def surface(state) do
      UI.surface("push-counter")
      |> UI.text("count", "#{state.count}")
      |> UI.root("count")
    end

    @impl true
    def handle_action(_, state), do: {:noreply, state}

    @impl true
    def handle_info(:tick, state) do
      new_state = %{state | count: state.count + 1}
      {:push_surface, surface(new_state), new_state}
    end

    def handle_info({:data_update, data}, state) do
      {:push_data, "push-counter", data, state}
    end
  end

  @port 14_832
  @push_port 14_833

  setup_all do
    Application.ensure_all_started(:gun)

    {:ok, server_pid} =
      A2UI.Server.start_link(
        provider: CounterProvider,
        port: @port,
        ip: {127, 0, 0, 1}
      )

    {:ok, push_pid} =
      A2UI.Server.start_link(
        provider: PushCounterProvider,
        port: @push_port,
        ip: {127, 0, 0, 1}
      )

    on_exit(fn ->
      Process.exit(server_pid, :shutdown)
      Process.exit(push_pid, :shutdown)
      Process.sleep(100)
    end)

    :ok
  end

  defp connect_ws do
    {:ok, conn_pid} = :gun.open(~c"127.0.0.1", @port)
    {:ok, :http} = :gun.await_up(conn_pid)
    stream_ref = :gun.ws_upgrade(conn_pid, ~c"/ws")

    receive do
      {:gun_upgrade, ^conn_pid, ^stream_ref, [<<"websocket">>], _headers} ->
        {:ok, conn_pid, stream_ref}
    after
      5_000 -> {:error, :upgrade_timeout}
    end
  end

  # v0.9: encode_surface returns a single JSON array, so one WS frame
  defp receive_ws_frame(conn_pid, stream_ref) do
    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, {:text, data}} -> data
    after
      5_000 -> flunk("Timeout waiting for WS frame")
    end
  end

  defp decode_messages(json) do
    Jason.decode!(json)
  end

  test "connects and receives initial surface" do
    {:ok, conn_pid, stream_ref} = connect_ws()

    # v0.9: single frame containing JSON array [updateComponents, createSurface]
    json = receive_ws_frame(conn_pid, stream_ref)
    messages = decode_messages(json)

    update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
    assert update["updateComponents"]["surfaceId"] == "counter"
    components = update["updateComponents"]["components"]
    assert length(components) == 3
    assert update["version"] == "v0.9"

    create = Enum.find(messages, &Map.has_key?(&1, "createSurface"))
    assert create["createSurface"]["rootComponentId"] == "main"

    :gun.close(conn_pid)
  end

  test "sends action and receives updated surface" do
    {:ok, conn_pid, stream_ref} = connect_ws()

    # Drain initial frame
    _initial = receive_ws_frame(conn_pid, stream_ref)

    # Send v0.9 action with event envelope
    action_json =
      Jason.encode!([
        %{
          "action" => %{
            "event" => %{"name" => "inc"},
            "surfaceId" => "counter"
          }
        }
      ])

    :gun.ws_send(conn_pid, stream_ref, {:text, action_json})

    # Receive updated surface (single frame, JSON array)
    response_json = receive_ws_frame(conn_pid, stream_ref)
    messages = decode_messages(response_json)

    update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
    assert update["updateComponents"]["surfaceId"] == "counter"

    # v0.9: properties at top level, literal values are plain
    components = update["updateComponents"]["components"]
    text_comp = Enum.find(components, &(&1["id"] == "count"))
    assert text_comp["component"] == "Text"
    assert text_comp["text"] == "1"

    :gun.close(conn_pid)
  end

  test "noreply action does not send response" do
    {:ok, conn_pid, stream_ref} = connect_ws()

    # Drain initial frame
    _initial = receive_ws_frame(conn_pid, stream_ref)

    # Send unknown action that triggers noreply
    action_json =
      Jason.encode!([
        %{
          "action" => %{
            "event" => %{"name" => "unknown"}
          }
        }
      ])

    :gun.ws_send(conn_pid, stream_ref, {:text, action_json})

    # Should not receive anything
    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, {:text, _data}} ->
        flunk("Should not have received a response for noreply action")
    after
      500 -> :ok
    end

    :gun.close(conn_pid)
  end

  test "serves index.html at root path" do
    {:ok, conn_pid} = :gun.open(~c"127.0.0.1", @port)
    {:ok, :http} = :gun.await_up(conn_pid)

    stream_ref = :gun.get(conn_pid, ~c"/")

    {status, headers, body} =
      receive do
        {:gun_response, ^conn_pid, ^stream_ref, :nofin, status, headers} ->
          {:ok, body} = :gun.await_body(conn_pid, stream_ref)
          {status, headers, body}
      after
        5_000 -> flunk("Timeout waiting for HTTP response")
      end

    assert status == 200
    content_type = :proplists.get_value(<<"content-type">>, headers)
    assert content_type =~ "text/html"
    assert body =~ "A2UI"

    :gun.close(conn_pid)
  end

  test "returns 404 for unknown paths" do
    {:ok, conn_pid} = :gun.open(~c"127.0.0.1", @port)
    {:ok, :http} = :gun.await_up(conn_pid)

    stream_ref = :gun.get(conn_pid, ~c"/nonexistent")

    receive do
      {:gun_response, ^conn_pid, ^stream_ref, _, 404, _headers} -> :ok
    after
      5_000 -> flunk("Timeout waiting for 404 response")
    end

    :gun.close(conn_pid)
  end

  # --- Push integration tests ---

  defp connect_push_ws do
    {:ok, conn_pid} = :gun.open(~c"127.0.0.1", @push_port)
    {:ok, :http} = :gun.await_up(conn_pid)
    stream_ref = :gun.ws_upgrade(conn_pid, ~c"/ws")

    receive do
      {:gun_upgrade, ^conn_pid, ^stream_ref, [<<"websocket">>], _headers} ->
        {:ok, conn_pid, stream_ref}
    after
      5_000 -> {:error, :upgrade_timeout}
    end
  end

  describe "push updates" do
    test "external process can push data model update to connected client" do
      {:ok, conn_pid, stream_ref} = connect_push_ws()

      # Drain initial surface frame
      _initial = receive_ws_frame(conn_pid, stream_ref)

      # Push data from external process via provider: option
      A2UI.Server.push_data("push-counter", %{"/status" => "active"},
        provider: PushCounterProvider
      )

      # Client should receive the data model update (v0.9 array)
      data_json = receive_ws_frame(conn_pid, stream_ref)
      [msg] = decode_messages(data_json)
      assert %{"updateDataModel" => %{"surfaceId" => "push-counter"}} = msg

      :gun.close(conn_pid)
    end

    test "external process can push surface update to connected client" do
      {:ok, conn_pid, stream_ref} = connect_push_ws()

      # Drain initial surface frame
      _initial = receive_ws_frame(conn_pid, stream_ref)

      # Push a full surface update via provider: option
      surface =
        A2UI.Builder.surface("push-counter")
        |> A2UI.Builder.text("count", "99")
        |> A2UI.Builder.root("count")

      A2UI.Server.push_surface(surface, provider: PushCounterProvider)

      # Client should receive single frame with [updateComponents, createSurface]
      json = receive_ws_frame(conn_pid, stream_ref)
      messages = decode_messages(json)
      update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
      assert update["updateComponents"]["surfaceId"] == "push-counter"

      :gun.close(conn_pid)
    end

    test "broadcast sends to multiple connected clients" do
      {:ok, conn1, ref1} = connect_push_ws()
      {:ok, conn2, ref2} = connect_push_ws()

      # Drain initial frames for both
      _initial1 = receive_ws_frame(conn1, ref1)
      _initial2 = receive_ws_frame(conn2, ref2)

      # Push data to all connections via provider: option
      A2UI.Server.push_data("push-counter", %{"/val" => 7}, provider: PushCounterProvider)

      # Both clients should receive
      json1 = receive_ws_frame(conn1, ref1)
      json2 = receive_ws_frame(conn2, ref2)

      [msg1] = decode_messages(json1)
      [msg2] = decode_messages(json2)
      assert %{"updateDataModel" => _} = msg1
      assert %{"updateDataModel" => _} = msg2

      :gun.close(conn1)
      :gun.close(conn2)
    end

    test "handle_info in provider triggers push to client" do
      {:ok, conn_pid, stream_ref} = connect_push_ws()

      # Drain initial frame
      _initial = receive_ws_frame(conn_pid, stream_ref)

      # Send :tick to all socket processes for this provider
      A2UI.Server.broadcast("push-counter", :tick, provider: PushCounterProvider)

      # Provider's handle_info(:tick, ...) returns {:push_surface, ...}
      # Client should receive single frame with messages array
      json = receive_ws_frame(conn_pid, stream_ref)
      messages = decode_messages(json)
      update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
      assert update["updateComponents"]["surfaceId"] == "push-counter"

      :gun.close(conn_pid)
    end

    test "broadcast_all sends to all connections via :__all__ key" do
      {:ok, conn_pid, stream_ref} = connect_push_ws()

      # Drain initial frame
      _initial = receive_ws_frame(conn_pid, stream_ref)

      # Use broadcast_all to send :tick to all sockets for this provider
      A2UI.Server.broadcast_all(:tick, provider: PushCounterProvider)

      # Provider's handle_info(:tick, ...) returns {:push_surface, ...}
      json = receive_ws_frame(conn_pid, stream_ref)
      messages = decode_messages(json)
      update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
      assert update["updateComponents"]["surfaceId"] == "push-counter"

      :gun.close(conn_pid)
    end
  end
end
