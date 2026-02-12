defmodule A2UI.SupervisorTest do
  use ExUnit.Case, async: true

  describe "registry_name/1" do
    test "returns deterministic name for a provider module" do
      assert A2UI.Supervisor.registry_name(MyApp.Provider) == A2UI.Registry.MyApp.Provider
    end

    test "returns consistent name across calls" do
      name1 = A2UI.Supervisor.registry_name(MyApp.Dashboard)
      name2 = A2UI.Supervisor.registry_name(MyApp.Dashboard)
      assert name1 == name2
    end

    test "returns different names for different providers" do
      name1 = A2UI.Supervisor.registry_name(MyApp.ProviderA)
      name2 = A2UI.Supervisor.registry_name(MyApp.ProviderB)
      refute name1 == name2
    end
  end

  describe "start_link/1 and init/1" do
    test "starts supervisor with Registry and Bandit children" do
      registry_name = :"test_registry_#{System.unique_integer([:positive])}"

      # Use a minimal Plug that returns 200
      plug = {Plug.Head, []}

      opts = [
        registry: registry_name,
        bandit_opts: [plug: plug, port: 0, ip: {127, 0, 0, 1}],
        name: :"test_sup_#{System.unique_integer([:positive])}"
      ]

      {:ok, pid} = start_supervised({A2UI.Supervisor, opts})
      assert Process.alive?(pid)

      # Registry should be started and usable
      assert {:ok, _} = Registry.register(registry_name, "test_key", %{})
    end

    test "registry is usable for duplicate key registration" do
      registry_name = :"test_registry_dup_#{System.unique_integer([:positive])}"

      plug = {Plug.Head, []}

      opts = [
        registry: registry_name,
        bandit_opts: [plug: plug, port: 0, ip: {127, 0, 0, 1}],
        name: :"test_sup_dup_#{System.unique_integer([:positive])}"
      ]

      {:ok, _pid} = start_supervised({A2UI.Supervisor, opts})

      # Duplicate keys should work (for broadcasting to multiple connections)
      task1 =
        Task.async(fn ->
          Registry.register(registry_name, "surface1", %{client: 1})
        end)

      task2 =
        Task.async(fn ->
          Registry.register(registry_name, "surface1", %{client: 2})
        end)

      assert {:ok, _} = Task.await(task1)
      assert {:ok, _} = Task.await(task2)
    end
  end
end
