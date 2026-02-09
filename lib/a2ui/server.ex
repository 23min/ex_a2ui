defmodule A2UI.Server do
  @moduledoc """
  Starts an A2UI WebSocket server, embeddable in any OTP supervision tree.

  ## Example

      # In your application supervisor:
      children = [
        {A2UI.Server,
         provider: MyApp.DashboardProvider,
         port: 4000}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)

  ## Options

  - `:provider` (required) — module implementing `A2UI.SurfaceProvider`
  - `:provider_opts` — map passed to `provider.init/1` (default: `%{}`)
  - `:port` — HTTP port (default: `4000`)
  - `:ip` — bind address (default: `{127, 0, 0, 1}`)

  All other options are forwarded to Bandit.
  """

  @doc "Returns a child specification for starting the A2UI server under a supervisor."
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    {provider, opts} = Keyword.pop!(opts, :provider)
    {provider_opts, opts} = Keyword.pop(opts, :provider_opts, %{})
    {port, opts} = Keyword.pop(opts, :port, 4000)
    {ip, opts} = Keyword.pop(opts, :ip, {127, 0, 0, 1})

    bandit_opts =
      Keyword.merge(opts,
        plug: {A2UI.Endpoint, [provider: provider, provider_opts: provider_opts]},
        port: port,
        ip: ip
      )

    %{
      id: __MODULE__,
      start: {Bandit, :start_link, [bandit_opts]},
      type: :supervisor
    }
  end

  @doc """
  Starts the A2UI server linked to the current process.

  See `child_spec/1` for available options.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    spec = child_spec(opts)
    {_module, _fun, [bandit_opts]} = spec.start
    Bandit.start_link(bandit_opts)
  end
end
