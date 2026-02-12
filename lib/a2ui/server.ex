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

  ## Push Updates

  Use `push_data/3` and `push_surface/2` to broadcast updates to all
  connected clients from external processes (timers, PubSub, GenServer casts):

      A2UI.Server.push_data("dashboard", %{"/uptime" => 42},
        provider: MyApp.DashboardProvider)

      A2UI.Server.push_surface(updated_surface,
        provider: MyApp.DashboardProvider)

  You can also pass `registry:` directly if you've already resolved it.
  """

  @doc "Returns a child specification for starting the A2UI server under a supervisor."
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    {provider, opts} = Keyword.pop!(opts, :provider)
    {provider_opts, opts} = Keyword.pop(opts, :provider_opts, %{})
    {port, opts} = Keyword.pop(opts, :port, 4000)
    {ip, opts} = Keyword.pop(opts, :ip, {127, 0, 0, 1})

    registry = A2UI.Supervisor.registry_name(provider)

    bandit_opts =
      Keyword.merge(opts,
        plug:
          {A2UI.Endpoint, [provider: provider, provider_opts: provider_opts, registry: registry]},
        port: port,
        ip: ip
      )

    %{
      id: __MODULE__,
      start:
        {A2UI.Supervisor, :start_link,
         [[registry: registry, bandit_opts: bandit_opts, name: :"a2ui_sup_#{provider}"]]},
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
    {module, fun, args} = spec.start
    apply(module, fun, args)
  end

  @doc """
  Broadcasts a data model update to all connected clients for the given surface.

  ## Options

  - `:provider` — the provider module (resolves registry automatically)
  - `:registry` — the Registry name directly (use one or the other)

  ## Examples

      A2UI.Server.push_data("dashboard", %{"/uptime" => 42}, provider: MyApp.Provider)
  """
  @spec push_data(String.t(), map(), keyword()) :: :ok
  def push_data(surface_id, data, opts) do
    registry = resolve_registry(opts)
    json = A2UI.Encoder.data_model_update(surface_id, data)
    dispatch(registry, surface_id, {:push_frame, {:text, json}})
  end

  @doc """
  Broadcasts a full surface update to all connected clients.

  ## Options

  - `:provider` — the provider module (resolves registry automatically)
  - `:registry` — the Registry name directly (use one or the other)

  ## Examples

      A2UI.Server.push_surface(updated_surface, provider: MyApp.Provider)
  """
  @spec push_surface(A2UI.Surface.t(), keyword()) :: :ok
  def push_surface(%A2UI.Surface{} = surface, opts) do
    registry = resolve_registry(opts)
    frames = surface |> A2UI.Encoder.encode_surface() |> Enum.map(&{:text, &1})
    dispatch(registry, surface.id, {:push_frames, frames})
  end

  @doc """
  Sends an arbitrary message to all connected socket processes for the given surface.

  ## Options

  - `:provider` — the provider module (resolves registry automatically)
  - `:registry` — the Registry name directly (use one or the other)
  """
  @spec broadcast(String.t(), term(), keyword()) :: :ok
  def broadcast(surface_id, message, opts) do
    registry = resolve_registry(opts)
    dispatch(registry, surface_id, message)
  end

  @doc """
  Sends an arbitrary message to all connected socket processes for the provider,
  regardless of surface ID.

  ## Options

  - `:provider` — the provider module (resolves registry automatically)
  - `:registry` — the Registry name directly (use one or the other)

  ## Examples

      A2UI.Server.broadcast_all(:tick, provider: MyApp.Provider)
  """
  @spec broadcast_all(term(), keyword()) :: :ok
  def broadcast_all(message, opts) do
    registry = resolve_registry(opts)
    dispatch(registry, :__all__, message)
  end

  defp resolve_registry(opts) do
    case Keyword.fetch(opts, :registry) do
      {:ok, registry} ->
        registry

      :error ->
        provider = Keyword.fetch!(opts, :provider)
        A2UI.Supervisor.registry_name(provider)
    end
  end

  defp dispatch(registry, key, message) do
    Registry.dispatch(registry, key, fn entries ->
      for {pid, _value} <- entries do
        send(pid, message)
      end
    end)
  end
end
