defmodule Demo.PushStreaming do
  @behaviour A2UI.SurfaceProvider

  alias A2UI.Builder, as: UI

  @impl true
  def init(_opts) do
    Process.send_after(self(), :tick, 1000)
    {:ok, %{uptime: 0, cpu: 42, memory: 68, requests: 0}}
  end

  @impl true
  def surface(state) do
    UI.surface("push-streaming")
    |> UI.theme(agent_display_name: "Push Streaming Demo")
    # Metrics
    |> UI.text("uptime-label", "Uptime:")
    |> UI.text("uptime-val", bind: "/metrics/uptime")
    |> UI.row("uptime-row", children: ["uptime-label", "uptime-val"])
    |> UI.text("cpu-label", "CPU:")
    |> UI.text("cpu-val", bind: "/metrics/cpu")
    |> UI.row("cpu-row", children: ["cpu-label", "cpu-val"])
    |> UI.text("mem-label", "Memory:")
    |> UI.text("mem-val", bind: "/metrics/memory")
    |> UI.row("mem-row", children: ["mem-label", "mem-val"])
    |> UI.text("req-label", "Requests:")
    |> UI.text("req-val", bind: "/metrics/requests")
    |> UI.row("req-row", children: ["req-label", "req-val"])
    |> UI.divider("div")
    |> UI.text("info", "Values update every second via push_data_path")
    # Layout
    |> UI.column("body", children: ["uptime-row", "cpu-row", "mem-row", "req-row", "div", "info"])
    |> UI.card("main", title: "Live Metrics", children: ["body"])
    |> UI.root("main")
    |> UI.data("/metrics/uptime", "#{state.uptime}s")
    |> UI.data("/metrics/cpu", "#{state.cpu}%")
    |> UI.data("/metrics/memory", "#{state.memory}%")
    |> UI.data("/metrics/requests", "#{state.requests}")
  end

  @impl true
  def handle_action(_, state), do: {:noreply, state}

  @impl true
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, 1000)

    new_state = %{
      state
      | uptime: state.uptime + 1,
        cpu: max(10, min(95, state.cpu + Enum.random(-5..5))),
        memory: max(30, min(90, state.memory + Enum.random(-2..2))),
        requests: state.requests + Enum.random(0..10)
    }

    # Use bulk data update for multiple values
    {:push_data, "push-streaming",
     %{
       "/metrics/uptime" => "#{new_state.uptime}s",
       "/metrics/cpu" => "#{new_state.cpu}%",
       "/metrics/memory" => "#{new_state.memory}%",
       "/metrics/requests" => "#{new_state.requests}"
     }, new_state}
  end
end
