defmodule A2UI.Socket do
  @moduledoc """
  WebSock handler implementing the A2UI message flow.

  Bridges WebSocket connections to an `A2UI.SurfaceProvider` implementation.
  On connection, calls the provider's `init/1` and `surface/1` to send the
  initial UI. On incoming `userAction` messages, calls `handle_action/2`.

  When a Registry is provided, the socket process registers itself on connect,
  enabling broadcast dispatch for push updates via `A2UI.Server.push_data/3`
  and `A2UI.Server.push_surface/2`.

  Arbitrary messages sent to the socket process are delegated to the provider's
  `handle_info/2` callback (if implemented).

  This module is not used directly by applications. It is configured
  internally by `A2UI.Endpoint`.
  """

  @behaviour WebSock

  require Logger

  defstruct [:provider, :provider_state, :surface_id, :registry]

  @type t :: %__MODULE__{
          provider: module(),
          provider_state: term(),
          surface_id: String.t() | nil,
          registry: atom() | nil
        }

  @impl WebSock
  def init(%{provider: provider, opts: opts} = args) do
    registry = Map.get(args, :registry)

    case provider.init(opts) do
      {:ok, provider_state} ->
        surface = provider.surface(provider_state)
        frames = encode_surface_frames(surface)

        if registry do
          Registry.register(registry, surface.id, %{})
          Registry.register(registry, :__all__, %{})
        end

        state = %__MODULE__{
          provider: provider,
          provider_state: provider_state,
          surface_id: surface.id,
          registry: registry
        }

        {:push, frames, state}

      {:error, reason} ->
        Logger.warning("A2UI.Socket: provider init failed: #{inspect(reason)}")

        {:push, [{:close, 1008, "Provider initialization failed"}],
         %__MODULE__{provider: provider, provider_state: nil}}
    end
  end

  @impl WebSock
  def handle_in({data, [opcode: :text]}, %__MODULE__{} = state) do
    case A2UI.Decoder.decode(data) do
      {:ok, {:user_action, action}} ->
        handle_provider_action(action, state)

      {:error, reason} ->
        Logger.warning("A2UI.Socket: decode error: #{inspect(reason)}")
        {:ok, state}
    end
  end

  def handle_in({_data, [opcode: :binary]}, state) do
    Logger.debug("A2UI.Socket: ignoring binary frame")
    {:ok, state}
  end

  @impl WebSock
  def handle_info({:push_frame, frame}, state) do
    {:push, [frame], state}
  end

  def handle_info({:push_frames, frames}, state) do
    {:push, frames, state}
  end

  def handle_info(msg, %__MODULE__{provider: provider} = state) do
    if function_exported?(provider, :handle_info, 2) do
      case provider.handle_info(msg, state.provider_state) do
        {:noreply, new_provider_state} ->
          {:ok, %{state | provider_state: new_provider_state}}

        {:push_data, surface_id, data, new_provider_state} ->
          json = A2UI.Encoder.data_model_update(surface_id, data)
          {:push, [{:text, json}], %{state | provider_state: new_provider_state}}

        {:push_surface, %A2UI.Surface{} = surface, new_provider_state} ->
          frames = encode_surface_frames(surface)
          {:push, frames, %{state | provider_state: new_provider_state}}

        other ->
          Logger.warning(
            "A2UI.Socket: invalid handle_info return from #{inspect(provider)}: #{inspect(other)}"
          )

          {:ok, state}
      end
    else
      Logger.debug("A2UI.Socket: unhandled info: #{inspect(msg)}")
      {:ok, state}
    end
  end

  @impl WebSock
  def terminate(reason, %__MODULE__{} = _state) do
    Logger.debug("A2UI.Socket: connection closed: #{inspect(reason)}")
    :ok
  end

  defp handle_provider_action(action, %__MODULE__{provider: provider} = state) do
    case provider.handle_action(action, state.provider_state) do
      {:noreply, new_provider_state} ->
        {:ok, %{state | provider_state: new_provider_state}}

      {:reply, %A2UI.Surface{} = surface, new_provider_state} ->
        frames = encode_surface_frames(surface)
        {:push, frames, %{state | provider_state: new_provider_state}}
    end
  end

  defp encode_surface_frames(%A2UI.Surface{} = surface) do
    surface
    |> A2UI.Encoder.encode_surface()
    |> Enum.map(&{:text, &1})
  end
end
