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

  @doc """
  Handle an arbitrary message sent to the socket process.

  This is **optional**. Implement it to react to timers, PubSub messages,
  GenServer casts, or any external event and push updates to the client.

  Return values:

  - `{:noreply, state}` — update state, send nothing to client
  - `{:push_data, surface_id, data, state}` — send a data model update
  - `{:push_surface, surface, state}` — send a full surface update

  ## Example: Timer-based push

      def init(_opts) do
        Process.send_after(self(), :tick, 1000)
        {:ok, %{uptime: 0}}
      end

      def handle_info(:tick, state) do
        Process.send_after(self(), :tick, 1000)
        new_state = %{state | uptime: state.uptime + 1}
        {:push_surface, surface(new_state), new_state}
      end

  ## Example: Phoenix.PubSub

      # Add {:phoenix_pubsub, "~> 2.1"} to your app's deps
      def init(_opts) do
        Phoenix.PubSub.subscribe(MyApp.PubSub, "updates")
        {:ok, %{}}
      end

      def handle_info({:data_changed, data}, state) do
        {:push_data, "dashboard", data, state}
      end
  """
  @callback handle_info(msg :: term(), state()) ::
              {:noreply, state()}
              | {:push_data, String.t(), map(), state()}
              | {:push_surface, A2UI.Surface.t(), state()}

  @doc """
  Handle a client error message.

  This is **optional**. Implement it to react to client-reported errors
  such as validation failures.

  Return values:

  - `{:noreply, state}` — acknowledge, send nothing to client
  - `{:push_surface, surface, state}` — send an updated surface in response

  ## Example

      def handle_error(%A2UI.Error{type: "VALIDATION_FAILED", path: path}, state) do
        Logger.warning("Validation failed at \#{path}")
        {:noreply, state}
      end
  """
  @callback handle_error(A2UI.Error.t(), state()) ::
              {:noreply, state()}
              | {:push_surface, A2UI.Surface.t(), state()}

  @optional_callbacks [handle_info: 2, handle_error: 2]
end
