defmodule A2UI.SSE do
  @moduledoc """
  Server-Sent Events (SSE) transport adapter for A2UI.

  Provides a push-only alternative to WebSocket for scenarios that don't
  require bidirectional communication — dashboards, monitoring panels,
  and other read-only surfaces.

  The client connects via `EventSource("/sse")` and receives A2UI messages
  as SSE events with `event: a2ui`.

  ## How it works

  The Plug request process itself becomes the long-lived SSE connection:
  1. Sets SSE response headers and starts chunked response
  2. Calls `provider.init/1` and `provider.surface/1` for the initial surface
  3. Registers in the Registry for push updates
  4. Enters a `receive` loop, forwarding push messages as SSE events

  ## SSE event format

      event: a2ui
      data: <json>

  """

  @behaviour Plug

  require Logger

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, config) do
    provider = config.provider
    provider_opts = config.provider_opts
    registry = config.registry

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("access-control-allow-origin", "*")
      |> send_chunked(200)

    case provider.init(provider_opts) do
      {:ok, provider_state} ->
        surface = provider.surface(provider_state)

        if registry do
          Registry.register(registry, surface.id, %{})
          Registry.register(registry, :__all__, %{})
        end

        # Send initial surface
        json = A2UI.Encoder.encode_surface(surface)
        {:ok, conn} = send_sse_event(conn, json)

        # Enter receive loop
        sse_loop(conn, provider, provider_state, surface.id, registry)

      {:error, reason} ->
        Logger.warning("A2UI.SSE: provider init failed: #{inspect(reason)}")
        {:ok, conn} = send_sse_event(conn, Jason.encode!(%{"error" => "init_failed"}))
        conn
    end
  end

  @doc false
  def send_sse_event(conn, data) do
    chunk(conn, "event: a2ui\ndata: #{data}\n\n")
  end

  @doc false
  def format_sse_event(data) do
    "event: a2ui\ndata: #{data}\n\n"
  end

  defp sse_loop(conn, provider, provider_state, surface_id, registry) do
    receive do
      {:push_frame, {:text, json}} ->
        case send_sse_event(conn, json) do
          {:ok, conn} ->
            sse_loop(conn, provider, provider_state, surface_id, registry)

          {:error, _reason} ->
            conn
        end

      msg ->
        case handle_provider_message(provider, msg, provider_state, surface_id) do
          {:noreply, new_state} ->
            sse_loop(conn, provider, new_state, surface_id, registry)

          {:send, json, new_state} ->
            case send_sse_event(conn, json) do
              {:ok, conn} ->
                sse_loop(conn, provider, new_state, surface_id, registry)

              {:error, _reason} ->
                conn
            end

          :ignore ->
            sse_loop(conn, provider, provider_state, surface_id, registry)
        end
    end
  end

  defp handle_provider_message(provider, msg, provider_state, _surface_id) do
    if function_exported?(provider, :handle_info, 2) do
      case provider.handle_info(msg, provider_state) do
        {:noreply, new_state} ->
          {:noreply, new_state}

        {:push_data, sid, data, new_state} ->
          json = A2UI.Encoder.update_data_model(sid, data)
          {:send, json, new_state}

        {:push_surface, %A2UI.Surface{} = surface, new_state} ->
          json = A2UI.Encoder.encode_surface(surface)
          {:send, json, new_state}

        {:push_data_path, sid, path, value, new_state} ->
          json = A2UI.Encoder.update_data_model_path(sid, path, value)
          {:send, json, new_state}

        {:delete_data_path, sid, path, new_state} ->
          json = A2UI.Encoder.delete_data_model_path(sid, path)
          {:send, json, new_state}

        other ->
          Logger.warning("A2UI.SSE: invalid handle_info return: #{inspect(other)}")
          :ignore
      end
    else
      Logger.debug("A2UI.SSE: unhandled message: #{inspect(msg)}")
      :ignore
    end
  end
end
