defmodule A2UI.EndpointTest do
  use ExUnit.Case, async: true

  defmodule DummyProvider do
    @behaviour A2UI.SurfaceProvider

    @impl true
    def init(_), do: {:ok, %{}}

    @impl true
    def surface(_), do: A2UI.Builder.surface("test") |> A2UI.Builder.text("t", "hi")

    @impl true
    def handle_action(_, s), do: {:noreply, s}
  end

  setup do
    opts = A2UI.Endpoint.init(provider: DummyProvider)
    {:ok, opts: opts}
  end

  test "GET / returns 200 with HTML content type", %{opts: opts} do
    conn =
      Plug.Test.conn(:get, "/")
      |> A2UI.Endpoint.call(opts)

    assert conn.status == 200

    assert {"content-type", content_type} =
             List.keyfind(conn.resp_headers, "content-type", 0)

    assert content_type =~ "text/html"
  end

  test "GET /nonexistent returns 404", %{opts: opts} do
    conn =
      Plug.Test.conn(:get, "/nonexistent")
      |> A2UI.Endpoint.call(opts)

    assert conn.status == 404
  end
end
