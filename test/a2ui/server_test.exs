defmodule A2UI.ServerTest do
  use ExUnit.Case, async: true

  defmodule DummyProvider do
    @behaviour A2UI.SurfaceProvider

    @impl true
    def init(_), do: {:ok, %{}}

    @impl true
    def surface(_), do: A2UI.Builder.surface("test")

    @impl true
    def handle_action(_, s), do: {:noreply, s}
  end

  describe "child_spec/1" do
    test "returns valid child spec with required options" do
      spec = A2UI.Server.child_spec(provider: DummyProvider)

      assert spec.id == A2UI.Server
      assert spec.type == :supervisor
      assert {A2UI.Supervisor, :start_link, [sup_opts]} = spec.start
      bandit_opts = Keyword.fetch!(sup_opts, :bandit_opts)
      assert Keyword.get(bandit_opts, :port) == 4000
      assert Keyword.get(bandit_opts, :ip) == {127, 0, 0, 1}
      assert {A2UI.Endpoint, endpoint_opts} = Keyword.get(bandit_opts, :plug)
      assert Keyword.get(endpoint_opts, :provider) == DummyProvider
      assert Keyword.get(endpoint_opts, :registry) == A2UI.Supervisor.registry_name(DummyProvider)
    end

    test "accepts custom port and ip" do
      spec = A2UI.Server.child_spec(provider: DummyProvider, port: 8080, ip: {0, 0, 0, 0})

      {A2UI.Supervisor, :start_link, [sup_opts]} = spec.start
      bandit_opts = Keyword.fetch!(sup_opts, :bandit_opts)
      assert Keyword.get(bandit_opts, :port) == 8080
      assert Keyword.get(bandit_opts, :ip) == {0, 0, 0, 0}
    end

    test "passes provider_opts through" do
      spec =
        A2UI.Server.child_spec(
          provider: DummyProvider,
          provider_opts: %{key: "value"}
        )

      {A2UI.Supervisor, :start_link, [sup_opts]} = spec.start
      bandit_opts = Keyword.fetch!(sup_opts, :bandit_opts)
      {A2UI.Endpoint, endpoint_opts} = Keyword.get(bandit_opts, :plug)
      assert Keyword.get(endpoint_opts, :provider_opts) == %{key: "value"}
    end

    test "includes registry in supervisor opts" do
      spec = A2UI.Server.child_spec(provider: DummyProvider)

      {A2UI.Supervisor, :start_link, [sup_opts]} = spec.start
      assert Keyword.get(sup_opts, :registry) == A2UI.Supervisor.registry_name(DummyProvider)
    end

    test "raises without :provider option" do
      assert_raise KeyError, fn ->
        A2UI.Server.child_spec([])
      end
    end
  end

  describe "push_data/3" do
    setup do
      registry_name = :"push_data_test_#{System.unique_integer([:positive])}"
      Registry.start_link(keys: :duplicate, name: registry_name)
      {:ok, registry: registry_name}
    end

    test "dispatches data model update to registered processes", %{registry: registry} do
      # Register this test process as a socket
      Registry.register(registry, "dashboard", %{})

      A2UI.Server.push_data("dashboard", %{"/count" => 42}, registry: registry)

      assert_receive {:push_frame, {:text, json}}
      [msg] = Jason.decode!(json)
      assert %{"updateDataModel" => %{"surfaceId" => "dashboard"}} = msg
      assert msg["version"] == "v0.9"
    end

    test "accepts provider: option to resolve registry", %{registry: _registry} do
      # Create a registry with the name that resolve_registry would produce
      provider = :"TestProvider_push_data_#{System.unique_integer([:positive])}"
      real_registry = A2UI.Supervisor.registry_name(provider)
      Registry.start_link(keys: :duplicate, name: real_registry)
      Registry.register(real_registry, "dashboard", %{})

      A2UI.Server.push_data("dashboard", %{"/count" => 42}, provider: provider)

      assert_receive {:push_frame, {:text, json}}
      [msg] = Jason.decode!(json)
      assert %{"updateDataModel" => %{"surfaceId" => "dashboard"}} = msg
    end

    test "is a no-op when no connections exist", %{registry: registry} do
      # Should not raise
      assert :ok = A2UI.Server.push_data("empty", %{"/x" => 1}, registry: registry)
    end
  end

  describe "push_surface/2" do
    setup do
      registry_name = :"push_surface_test_#{System.unique_integer([:positive])}"
      Registry.start_link(keys: :duplicate, name: registry_name)
      {:ok, registry: registry_name}
    end

    test "dispatches surface update to registered processes", %{registry: registry} do
      Registry.register(registry, "test-surface", %{})

      surface =
        A2UI.Builder.surface("test-surface")
        |> A2UI.Builder.text("t", "hello")
        |> A2UI.Builder.root("t")

      A2UI.Server.push_surface(surface, registry: registry)

      assert_receive {:push_frame, {:text, json}}
      messages = Jason.decode!(json)
      update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
      assert update["updateComponents"]["surfaceId"] == "test-surface"
    end

    test "is a no-op when no connections exist", %{registry: registry} do
      surface = A2UI.Builder.surface("empty")
      assert :ok = A2UI.Server.push_surface(surface, registry: registry)
    end
  end

  describe "broadcast/3" do
    setup do
      registry_name = :"broadcast_test_#{System.unique_integer([:positive])}"
      Registry.start_link(keys: :duplicate, name: registry_name)
      {:ok, registry: registry_name}
    end

    test "sends arbitrary message to all registered processes", %{registry: registry} do
      Registry.register(registry, "surface1", %{})

      A2UI.Server.broadcast("surface1", {:custom, :hello}, registry: registry)

      assert_receive {:custom, :hello}
    end

    test "sends to multiple registered processes", %{registry: registry} do
      parent = self()

      task1 =
        Task.async(fn ->
          Registry.register(registry, "multi", %{})
          send(parent, :task1_ready)

          receive do
            msg -> send(parent, {:task1_got, msg})
          end
        end)

      task2 =
        Task.async(fn ->
          Registry.register(registry, "multi", %{})
          send(parent, :task2_ready)

          receive do
            msg -> send(parent, {:task2_got, msg})
          end
        end)

      assert_receive :task1_ready
      assert_receive :task2_ready

      A2UI.Server.broadcast("multi", :ping, registry: registry)

      assert_receive {:task1_got, :ping}
      assert_receive {:task2_got, :ping}

      Task.await(task1)
      Task.await(task2)
    end
  end

  describe "broadcast_all/2" do
    setup do
      registry_name = :"broadcast_all_test_#{System.unique_integer([:positive])}"
      Registry.start_link(keys: :duplicate, name: registry_name)
      {:ok, registry: registry_name}
    end

    test "sends message to all processes registered under :__all__", %{registry: registry} do
      Registry.register(registry, :__all__, %{})

      A2UI.Server.broadcast_all(:ping, registry: registry)

      assert_receive :ping
    end

    test "reaches processes with different surface IDs", %{registry: registry} do
      parent = self()

      task1 =
        Task.async(fn ->
          Registry.register(registry, "surface-a", %{})
          Registry.register(registry, :__all__, %{})
          send(parent, :task1_ready)

          receive do
            msg -> send(parent, {:task1_got, msg})
          end
        end)

      task2 =
        Task.async(fn ->
          Registry.register(registry, "surface-b", %{})
          Registry.register(registry, :__all__, %{})
          send(parent, :task2_ready)

          receive do
            msg -> send(parent, {:task2_got, msg})
          end
        end)

      assert_receive :task1_ready
      assert_receive :task2_ready

      A2UI.Server.broadcast_all(:hello, registry: registry)

      assert_receive {:task1_got, :hello}
      assert_receive {:task2_got, :hello}

      Task.await(task1)
      Task.await(task2)
    end

    test "is a no-op when no connections exist", %{registry: registry} do
      assert :ok = A2UI.Server.broadcast_all(:ping, registry: registry)
    end
  end
end
