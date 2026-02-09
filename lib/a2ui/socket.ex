defmodule A2UI.Socket do
  @moduledoc """
  WebSock handler implementing the A2UI message flow.

  Bridges WebSocket connections to an `A2UI.SurfaceProvider` implementation.
  On connection, calls the provider's `init/1` and `surface/1` to send the
  initial UI. On incoming `userAction` messages, calls `handle_action/2`.

  This module is not used directly by applications. It is configured
  internally by `A2UI.Endpoint`.
  """

  @behaviour WebSock

  require Logger

  defstruct [:provider, :provider_state]

  @type t :: %__MODULE__{
          provider: module(),
          provider_state: term()
        }

  @impl WebSock
  def init(%{provider: provider, opts: opts}) do
    case provider.init(opts) do
      {:ok, provider_state} ->
        surface = provider.surface(provider_state)
        frames = encode_surface_frames(surface)

        state = %__MODULE__{
          provider: provider,
          provider_state: provider_state
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
  def handle_info(msg, state) do
    Logger.debug("A2UI.Socket: unhandled info: #{inspect(msg)}")
    {:ok, state}
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
