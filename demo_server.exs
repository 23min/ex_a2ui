defmodule DemoProvider do
  @behaviour A2UI.SurfaceProvider

  alias A2UI.Builder, as: UI

  @impl true
  def init(_opts) do
    # Start a 1-second timer for push updates
    Process.send_after(self(), :tick, 1000)
    {:ok, %{count: 0, health: "operational", uptime: 0}}
  end

  @impl true
  def surface(state) do
    UI.surface("demo")
    |> UI.text("title", "A2UI Demo")
    |> UI.text("count-label", "Counter:")
    |> UI.text("count-val", "#{state.count}")
    |> UI.text("health-label", "Health:")
    |> UI.text("health-val", state.health)
    |> UI.text("uptime-label", "Uptime:")
    |> UI.text("uptime-val", "#{state.uptime}s")
    |> UI.button("inc", "Increment", action: "increment")
    |> UI.button("reset", "Reset", action: "reset")
    |> UI.row("count-row", children: ["count-label", "count-val"])
    |> UI.row("health-row", children: ["health-label", "health-val"])
    |> UI.row("uptime-row", children: ["uptime-label", "uptime-val"])
    |> UI.row("actions", children: ["inc", "reset"])
    |> UI.column("body", children: ["count-row", "health-row", "uptime-row", "actions"])
    |> UI.card("main", children: ["title", "body"], title: "Dashboard")
    |> UI.root("main")
  end

  @impl true
  def handle_action(%A2UI.Action{name: "increment"}, state) do
    new = %{state | count: state.count + 1}
    {:reply, surface(new), new}
  end

  def handle_action(%A2UI.Action{name: "reset"}, state) do
    new = %{state | count: 0}
    {:reply, surface(new), new}
  end

  def handle_action(_, state), do: {:noreply, state}

  @impl true
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, 1000)
    new = %{state | uptime: state.uptime + 1}
    {:push_surface, surface(new), new}
  end
end

IO.puts("Starting A2UI demo server on http://localhost:4000")
IO.puts("Open in browser to see the debug renderer")
IO.puts("Press Ctrl+C to stop\n")

{:ok, _pid} = A2UI.Server.start_link(provider: DemoProvider, port: 4000)

Process.sleep(:infinity)
