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

  @port 14_832

  setup_all do
    Application.ensure_all_started(:gun)

    {:ok, server_pid} =
      A2UI.Server.start_link(
        provider: CounterProvider,
        port: @port,
        ip: {127, 0, 0, 1}
      )

    on_exit(fn ->
      Process.exit(server_pid, :shutdown)
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

  defp receive_ws_frames(conn_pid, stream_ref, count, acc \\ []) do
    if length(acc) >= count do
      Enum.reverse(acc)
    else
      receive do
        {:gun_ws, ^conn_pid, ^stream_ref, {:text, data}} ->
          receive_ws_frames(conn_pid, stream_ref, count, [data | acc])
      after
        5_000 -> {:error, :timeout, Enum.reverse(acc)}
      end
    end
  end

  test "connects and receives initial surface" do
    {:ok, conn_pid, stream_ref} = connect_ws()

    # surfaceUpdate + beginRendering (no data)
    frames = receive_ws_frames(conn_pid, stream_ref, 2)

    [surface_update_json, begin_rendering_json] = frames

    surface_update = Jason.decode!(surface_update_json)
    assert %{"surfaceUpdate" => %{"surfaceId" => "counter"}} = surface_update
    components = surface_update["surfaceUpdate"]["components"]
    assert length(components) == 3

    begin_rendering = Jason.decode!(begin_rendering_json)
    assert %{"beginRendering" => %{"rootComponentId" => "main"}} = begin_rendering

    :gun.close(conn_pid)
  end

  test "sends userAction and receives updated surface" do
    {:ok, conn_pid, stream_ref} = connect_ws()

    # Drain initial frames
    _initial = receive_ws_frames(conn_pid, stream_ref, 2)

    # Send increment action
    action_json =
      Jason.encode!(%{
        "userAction" => %{"action" => %{"name" => "inc"}}
      })

    :gun.ws_send(conn_pid, stream_ref, {:text, action_json})

    # Receive updated surface (surfaceUpdate + beginRendering)
    response = receive_ws_frames(conn_pid, stream_ref, 2)

    [update_json, _render_json] = response
    update = Jason.decode!(update_json)
    assert %{"surfaceUpdate" => %{"surfaceId" => "counter"}} = update

    # The count text should now show "1"
    components = update["surfaceUpdate"]["components"]
    text_comp = Enum.find(components, &(&1["id"] == "count"))
    assert text_comp["component"]["Text"]["text"]["literalString"] == "1"

    :gun.close(conn_pid)
  end

  test "noreply action does not send response" do
    {:ok, conn_pid, stream_ref} = connect_ws()

    # Drain initial frames
    _initial = receive_ws_frames(conn_pid, stream_ref, 2)

    # Send unknown action that triggers noreply
    action_json =
      Jason.encode!(%{
        "userAction" => %{"action" => %{"name" => "unknown"}}
      })

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
end
