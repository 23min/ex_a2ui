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

  defmodule PushProvider do
    @behaviour A2UI.SurfaceProvider

    alias A2UI.Builder, as: UI

    @impl true
    def init(opts), do: {:ok, Map.merge(%{count: 0}, opts)}

    @impl true
    def surface(state) do
      UI.surface("push-test")
      |> UI.text("count", "#{state.count}")
      |> UI.root("count")
    end

    @impl true
    def handle_action(_, state), do: {:noreply, state}

    @impl true
    def handle_info(:tick, state) do
      new_state = %{state | count: state.count + 1}
      {:push_surface, surface(new_state), new_state}
    end

    def handle_info({:push_data, surface_id, data}, state) do
      {:push_data, surface_id, data, state}
    end

    def handle_info(:noop, state) do
      {:noreply, state}
    end

    def handle_info({:push_data_path, surface_id, path, value}, state) do
      {:push_data_path, surface_id, path, value, state}
    end

    def handle_info({:delete_data_path, surface_id, path}, state) do
      {:delete_data_path, surface_id, path, state}
    end
  end

  defmodule ErrorProvider do
    @behaviour A2UI.SurfaceProvider

    alias A2UI.Builder, as: UI

    @impl true
    def init(opts), do: {:ok, Map.merge(%{errors: []}, opts)}

    @impl true
    def surface(_state) do
      UI.surface("error-test")
      |> UI.text("msg", "OK")
      |> UI.root("msg")
    end

    @impl true
    def handle_action(_, state), do: {:noreply, state}

    @impl true
    def handle_error(%A2UI.Error{} = error, state) do
      new_state = %{state | errors: [error | state.errors]}
      {:noreply, new_state}
    end
  end

  defmodule ErrorPushProvider do
    @behaviour A2UI.SurfaceProvider

    alias A2UI.Builder, as: UI

    @impl true
    def init(opts), do: {:ok, Map.merge(%{}, opts)}

    @impl true
    def surface(_state) do
      UI.surface("error-push-test")
      |> UI.text("msg", "OK")
      |> UI.root("msg")
    end

    @impl true
    def handle_action(_, state), do: {:noreply, state}

    @impl true
    def handle_error(%A2UI.Error{}, state) do
      {:push_surface, surface(state), state}
    end
  end

  describe "init/1" do
    test "calls provider and sends initial surface as single frame" do
      {:push, frames, state} =
        Socket.init(%{provider: CounterProvider, opts: %{}})

      assert %Socket{provider: CounterProvider, provider_state: %{count: 0}} = state

      # v0.9: encode_surface returns a single JSON array, so one frame
      assert length(frames) == 1

      {:text, json} = hd(frames)
      messages = Jason.decode!(json)
      assert is_list(messages)

      update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
      assert update["updateComponents"]["surfaceId"] == "counter"
      assert update["version"] == "v0.9"

      create = Enum.find(messages, &Map.has_key?(&1, "createSurface"))
      assert create["createSurface"]["rootComponentId"] == "main"
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

    test "decodes v0.9 action and calls provider", %{state: state} do
      json =
        Jason.encode!([
          %{"action" => %{"event" => %{"name" => "inc"}, "surfaceId" => "counter"}}
        ])

      {:push, frames, new_state} = Socket.handle_in({json, [opcode: :text]}, state)

      assert new_state.provider_state.count == 1
      assert length(frames) >= 1

      {:text, first} = hd(frames)
      messages = Jason.decode!(first)
      update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
      assert update["updateComponents"]["surfaceId"] == "counter"
    end

    test "handles noreply from provider", %{state: state} do
      json =
        Jason.encode!([
          %{"action" => %{"event" => %{"name" => "noop"}}}
        ])

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
    test "push_frame sends a single frame to client" do
      {:push, _frames, state} =
        Socket.init(%{provider: CounterProvider, opts: %{}})

      json = A2UI.Encoder.update_data_model("counter", %{"/count" => 5})
      {:push, [frame], ^state} = Socket.handle_info({:push_frame, {:text, json}}, state)

      assert {:text, ^json} = frame
    end

    test "push_frames sends multiple frames to client" do
      {:push, _frames, state} =
        Socket.init(%{provider: CounterProvider, opts: %{}})

      frames = [{:text, "frame1"}, {:text, "frame2"}]
      {:push, ^frames, ^state} = Socket.handle_info({:push_frames, frames}, state)
    end

    test "delegates to provider handle_info when implemented — push_surface" do
      {:push, _frames, state} =
        Socket.init(%{provider: PushProvider, opts: %{}})

      {:push, frames, new_state} = Socket.handle_info(:tick, state)

      assert new_state.provider_state.count == 1
      assert length(frames) == 1

      {:text, json} = hd(frames)
      messages = Jason.decode!(json)
      update = Enum.find(messages, &Map.has_key?(&1, "updateComponents"))
      assert update["updateComponents"]["surfaceId"] == "push-test"
    end

    test "delegates to provider handle_info when implemented — push_data" do
      {:push, _frames, state} =
        Socket.init(%{provider: PushProvider, opts: %{}})

      data = %{"/health" => "degraded"}

      {:push, [{:text, json}], new_state} =
        Socket.handle_info({:push_data, "push-test", data}, state)

      assert new_state.provider_state == state.provider_state
      [msg] = Jason.decode!(json)
      assert %{"updateDataModel" => %{"surfaceId" => "push-test"}} = msg
    end

    test "delegates to provider handle_info when implemented — noreply" do
      {:push, _frames, state} =
        Socket.init(%{provider: PushProvider, opts: %{}})

      {:ok, same_state} = Socket.handle_info(:noop, state)
      assert same_state.provider_state == state.provider_state
    end

    test "ignores unknown messages when provider has no handle_info" do
      {:push, _frames, state} =
        Socket.init(%{provider: CounterProvider, opts: %{}})

      {:ok, same_state} = Socket.handle_info(:some_message, state)
      assert same_state == state
    end

    test "registers in registry when provided" do
      registry_name = :"test_socket_registry_#{System.unique_integer([:positive])}"
      Registry.start_link(keys: :duplicate, name: registry_name)

      {:push, _frames, state} =
        Socket.init(%{provider: PushProvider, opts: %{}, registry: registry_name})

      assert state.registry == registry_name
      assert state.surface_id == "push-test"

      # The process should be registered under surface_id
      entries = Registry.lookup(registry_name, "push-test")
      assert length(entries) == 1
      {pid, value} = hd(entries)
      assert pid == self()
      assert value == %{}
    end

    test "handle_info delegates push_data_path return" do
      {:push, _frames, state} =
        Socket.init(%{provider: PushProvider, opts: %{}})

      {:push, frames, _new_state} =
        Socket.handle_info({:push_data_path, "push-test", "/count", 99}, state)

      assert [{:text, json}] = frames
      [msg] = Jason.decode!(json)
      assert msg["updateDataModel"]["path"] == "/count"
      assert msg["updateDataModel"]["value"] == 99
    end

    test "handle_info delegates delete_data_path return" do
      {:push, _frames, state} =
        Socket.init(%{provider: PushProvider, opts: %{}})

      {:push, frames, _new_state} =
        Socket.handle_info({:delete_data_path, "push-test", "/removed"}, state)

      assert [{:text, json}] = frames
      [msg] = Jason.decode!(json)
      assert msg["updateDataModel"]["path"] == "/removed"
      refute Map.has_key?(msg["updateDataModel"], "value")
    end

    test "registers under :__all__ key for provider-wide broadcast" do
      registry_name = :"test_socket_registry_all_#{System.unique_integer([:positive])}"
      Registry.start_link(keys: :duplicate, name: registry_name)

      {:push, _frames, _state} =
        Socket.init(%{provider: PushProvider, opts: %{}, registry: registry_name})

      # The process should also be registered under :__all__
      entries = Registry.lookup(registry_name, :__all__)
      assert length(entries) == 1
      {pid, _value} = hd(entries)
      assert pid == self()
    end
  end

  describe "handle_in/2 with error messages" do
    test "routes error to provider handle_error — noreply" do
      {:push, _frames, state} =
        Socket.init(%{provider: ErrorProvider, opts: %{}})

      json =
        Jason.encode!([
          %{
            "error" => %{
              "type" => "VALIDATION_FAILED",
              "path" => "/form/email",
              "message" => "Invalid"
            }
          }
        ])

      {:ok, new_state} = Socket.handle_in({json, [opcode: :text]}, state)
      assert length(new_state.provider_state.errors) == 1
      assert hd(new_state.provider_state.errors).type == "VALIDATION_FAILED"
    end

    test "routes error to provider handle_error — push_surface" do
      {:push, _frames, state} =
        Socket.init(%{provider: ErrorPushProvider, opts: %{}})

      json =
        Jason.encode!([
          %{"error" => %{"type" => "VALIDATION_FAILED", "path" => "/field"}}
        ])

      {:push, frames, _new_state} = Socket.handle_in({json, [opcode: :text]}, state)
      assert length(frames) >= 1
      {:text, response_json} = hd(frames)
      messages = Jason.decode!(response_json)
      assert Enum.any?(messages, &Map.has_key?(&1, "updateComponents"))
    end

    test "ignores errors when provider has no handle_error" do
      {:push, _frames, state} =
        Socket.init(%{provider: CounterProvider, opts: %{}})

      json =
        Jason.encode!([
          %{"error" => %{"type" => "GENERIC", "message" => "Something failed"}}
        ])

      {:ok, same_state} = Socket.handle_in({json, [opcode: :text]}, state)
      assert same_state.provider_state == state.provider_state
    end

    test "handles mixed action and error messages" do
      {:push, _frames, state} =
        Socket.init(%{provider: ErrorProvider, opts: %{}})

      json =
        Jason.encode!([
          %{"error" => %{"type" => "VALIDATION_FAILED", "path" => "/x"}}
        ])

      {:ok, new_state} = Socket.handle_in({json, [opcode: :text]}, state)
      assert length(new_state.provider_state.errors) == 1
    end
  end
end
