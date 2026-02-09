defmodule A2UI.SurfaceProvider do
  @moduledoc """
  Behaviour for defining A2UI surfaces and handling user actions.

  Implement this behaviour to serve interactive UI surfaces over WebSocket.
  The server calls your callbacks when a client connects and when users
  interact with your surface.

  ## Example

      defmodule MyApp.DashboardProvider do
        @behaviour A2UI.SurfaceProvider

        alias A2UI.Builder, as: UI

        @impl true
        def init(_opts), do: {:ok, %{counter: 0}}

        @impl true
        def surface(state) do
          UI.surface("dashboard")
          |> UI.text("count", "Count: \#{state.counter}")
          |> UI.button("inc", "Increment", action: "increment")
          |> UI.card("main", children: ["count", "inc"])
          |> UI.root("main")
        end

        @impl true
        def handle_action(%A2UI.Action{name: "increment"}, state) do
          new_state = %{state | counter: state.counter + 1}
          {:reply, surface(new_state), new_state}
        end

        def handle_action(_action, state), do: {:noreply, state}
      end
  """

  @type state :: term()

  @doc """
  Called when a new WebSocket connection is established.

  Receives connection options (currently an empty map; future versions
  may include query params and headers).

  Return `{:ok, state}` to accept the connection, or
  `{:error, reason}` to reject it (the WebSocket will be closed).
  """
  @callback init(opts :: map()) :: {:ok, state()} | {:error, term()}

  @doc """
  Build the current surface from state.

  Called after `init/1` to produce the initial surface sent to the client.
  Also called by the application to produce a fresh surface from current state.
  """
  @callback surface(state()) :: A2UI.Surface.t()

  @doc """
  Handle a user action received from the client.

  Return `{:noreply, state}` to acknowledge without sending a response,
  or `{:reply, surface, state}` to send an updated surface to the client.
  """
  @callback handle_action(A2UI.Action.t(), state()) ::
              {:noreply, state()}
              | {:reply, A2UI.Surface.t(), state()}
end
