defmodule A2UI.SocketTest do
  use ExUnit.Case, async: true

  alias A2UI.Socket

  defmodule CounterProvider do
    @behaviour A2UI.SurfaceProvider

    alias A2UI.Builder, as: UI

    @impl true
    def init(%{fail: true}), do: {:error, :test_failure}
    def init(opts), do: {:ok, Map.merge(%{count: 0}, opts)}

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
      new_state = %{state | count: state.count + 1}
      {:reply, surface(new_state), new_state}
    end

    def handle_action(%A2UI.Action{name: "noop"}, state) do
      {:noreply, state}
    end
  end

  describe "init/1" do
    test "calls provider and sends initial surface frames" do
      {:push, frames, state} =
        Socket.init(%{provider: CounterProvider, opts: %{}})

      assert %Socket{provider: CounterProvider, provider_state: %{count: 0}} = state

      # surfaceUpdate + beginRendering (no data model)
      assert length(frames) == 2

      Enum.each(frames, fn {:text, json} ->
        assert is_binary(json)
        assert {:ok, _} = Jason.decode(json)
      end)

      {:text, first} = hd(frames)
      assert %{"surfaceUpdate" => _} = Jason.decode!(first)

      {:text, last} = List.last(frames)
      assert %{"beginRendering" => _} = Jason.decode!(last)
    end

    test "sends close frame when provider init fails" do
      {:push, frames, _state} =
        Socket.init(%{provider: CounterProvider, opts: %{fail: true}})

      assert [{:close, 1008, _msg}] = frames
    end
  end

  describe "handle_in/2" do
    setup do
      {:push, _frames, state} =
        Socket.init(%{provider: CounterProvider, opts: %{}})

      {:ok, state: state}
    end

    test "decodes userAction and calls provider", %{state: state} do
      json = Jason.encode!(%{"userAction" => %{"action" => %{"name" => "inc"}}})
      {:push, frames, new_state} = Socket.handle_in({json, [opcode: :text]}, state)

      assert new_state.provider_state.count == 1
      assert length(frames) >= 1

      {:text, first} = hd(frames)
      decoded = Jason.decode!(first)
      assert decoded["surfaceUpdate"]["surfaceId"] == "counter"
    end

    test "handles noreply from provider", %{state: state} do
      json = Jason.encode!(%{"userAction" => %{"action" => %{"name" => "noop"}}})
      {:ok, new_state} = Socket.handle_in({json, [opcode: :text]}, state)

      assert new_state.provider_state.count == 0
    end

    test "ignores malformed JSON", %{state: state} do
      {:ok, same_state} = Socket.handle_in({"not json", [opcode: :text]}, state)
      assert same_state == state
    end

    test "ignores unknown message types", %{state: state} do
      json = Jason.encode!(%{"unknownType" => %{}})
      {:ok, same_state} = Socket.handle_in({json, [opcode: :text]}, state)
      assert same_state == state
    end

    test "ignores binary frames", %{state: state} do
      {:ok, same_state} = Socket.handle_in({<<0, 1, 2>>, [opcode: :binary]}, state)
      assert same_state == state
    end
  end

  describe "handle_info/2" do
    test "ignores unknown messages" do
      {:push, _frames, state} =
        Socket.init(%{provider: CounterProvider, opts: %{}})

      {:ok, same_state} = Socket.handle_info(:some_message, state)
      assert same_state == state
    end
  end
end
