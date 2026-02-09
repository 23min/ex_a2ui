defmodule A2UI.SurfaceProviderTest do
  use ExUnit.Case, async: true

  defmodule TestProvider do
    @behaviour A2UI.SurfaceProvider

    alias A2UI.Builder, as: UI

    @impl true
    def init(_opts), do: {:ok, %{count: 0}}

    @impl true
    def surface(state) do
      UI.surface("test")
      |> UI.text("count", "Count: #{state.count}")
      |> UI.button("inc", "Increment", action: "increment")
      |> UI.card("main", children: ["count", "inc"])
      |> UI.root("main")
    end

    @impl true
    def handle_action(%A2UI.Action{name: "increment"}, state) do
      new_state = %{state | count: state.count + 1}
      {:reply, surface(new_state), new_state}
    end

    def handle_action(_action, state), do: {:noreply, state}
  end

  test "TestProvider implements all required callbacks" do
    assert function_exported?(TestProvider, :init, 1)
    assert function_exported?(TestProvider, :surface, 1)
    assert function_exported?(TestProvider, :handle_action, 2)
  end

  test "init returns {:ok, state}" do
    assert {:ok, %{count: 0}} = TestProvider.init(%{})
  end

  test "surface returns a Surface struct" do
    {:ok, state} = TestProvider.init(%{})
    surface = TestProvider.surface(state)
    assert %A2UI.Surface{id: "test"} = surface
    assert A2UI.Surface.component_count(surface) == 3
  end

  test "handle_action with :reply returns updated surface" do
    {:ok, state} = TestProvider.init(%{})
    action = %A2UI.Action{name: "increment"}
    {:reply, surface, new_state} = TestProvider.handle_action(action, state)
    assert %A2UI.Surface{} = surface
    assert new_state.count == 1
  end

  test "handle_action with :noreply returns state" do
    {:ok, state} = TestProvider.init(%{})
    action = %A2UI.Action{name: "unknown"}
    assert {:noreply, ^state} = TestProvider.handle_action(action, state)
  end
end
