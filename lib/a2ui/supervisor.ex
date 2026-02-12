defmodule A2UI.Supervisor do
  @moduledoc """
  OTP Supervisor that starts a Registry (for connection tracking) alongside Bandit.

  Socket processes register themselves on connect via the Registry, enabling
  broadcast dispatch for push updates.

  This module is used internally by `A2UI.Server`. Applications do not need
  to interact with it directly.
  """

  use Supervisor

  @doc false
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @impl Supervisor
  def init(opts) do
    {registry_name, opts} = Keyword.pop!(opts, :registry)
    {bandit_opts, _rest} = Keyword.pop!(opts, :bandit_opts)

    children = [
      {Registry, keys: :duplicate, name: registry_name},
      {Bandit, bandit_opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @doc """
  Returns the deterministic Registry name for a given provider module.

  ## Examples

      iex> A2UI.Supervisor.registry_name(MyApp.DashboardProvider)
      A2UI.Registry.MyApp.DashboardProvider
  """
  @spec registry_name(module()) :: atom()
  def registry_name(provider) when is_atom(provider) do
    Module.concat(A2UI.Registry, provider)
  end
end
