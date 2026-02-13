defmodule A2UI.Endpoint do
  @moduledoc """
  Plug endpoint for A2UI HTTP, WebSocket, and SSE connections.

  Routes:
  - `GET /ws` — WebSocket upgrade (A2UI protocol)
  - `GET /sse` — Server-Sent Events stream (push-only)
  - `GET /` — serves the default A2UI renderer page
  - Static assets from `priv/static/`

  This module is used internally by `A2UI.Server`. Applications
  do not need to interact with it directly.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts) do
    provider = Keyword.fetch!(opts, :provider)
    provider_opts = Keyword.get(opts, :provider_opts, %{})
    registry = Keyword.get(opts, :registry)

    static_opts =
      Plug.Static.init(
        at: "/",
        from: {:ex_a2ui, "priv/static"}
      )

    %{
      provider: provider,
      provider_opts: provider_opts,
      registry: registry,
      static_opts: static_opts
    }
  end

  @impl Plug
  def call(%{path_info: ["ws"]} = conn, config) do
    conn = Plug.Conn.fetch_query_params(conn)
    opts = Map.merge(config.provider_opts, %{query_params: conn.query_params})

    conn
    |> WebSockAdapter.upgrade(
      A2UI.Socket,
      %{provider: config.provider, opts: opts, registry: config.registry},
      timeout: 60_000
    )
    |> halt()
  end

  def call(%{path_info: ["sse"]} = conn, config) do
    conn = Plug.Conn.fetch_query_params(conn)

    sse_config = %{
      config
      | provider_opts: Map.merge(config.provider_opts, %{query_params: conn.query_params})
    }

    A2UI.SSE.call(conn, sse_config)
  end

  def call(%{path_info: []} = conn, _config) do
    index = Application.app_dir(:ex_a2ui, "priv/static/index.html")

    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, index)
  end

  def call(conn, config) do
    conn = Plug.Static.call(conn, config.static_opts)

    if conn.halted do
      conn
    else
      send_resp(conn, 404, "Not Found")
    end
  end
end
