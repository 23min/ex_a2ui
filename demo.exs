alias A2UI.Builder, as: UI

IO.puts("=== ex_a2ui Demo ===\n")

# Build a realistic dashboard surface
surface =
  UI.surface("app-status")
  |> UI.text("title", "Application Dashboard")
  |> UI.text("health-label", "System Health:")
  |> UI.text("health-value", bind: "/system/health")
  |> UI.text("uptime-label", "Uptime:")
  |> UI.text("uptime-value", bind: "/system/uptime")
  |> UI.button("refresh", "Refresh Status", action: "refresh")
  |> UI.button("restart", "Restart Service", action: "restart_service")
  |> UI.checkbox("auto-refresh", label: "Auto-refresh", bind: "/settings/auto_refresh")
  |> UI.divider("sep1")
  |> UI.row("health-row", children: ["health-label", "health-value"])
  |> UI.row("uptime-row", children: ["uptime-label", "uptime-value"])
  |> UI.row("actions", children: ["refresh", "restart", "auto-refresh"])
  |> UI.column("body", children: ["health-row", "uptime-row", "sep1", "actions"])
  |> UI.card("main", children: ["title", "body"], title: "Status")
  |> UI.data("/system/health", "operational")
  |> UI.data("/system/uptime", "3d 14h 22m")
  |> UI.data("/settings/auto_refresh", true)
  |> UI.root("main")

IO.puts("Surface: #{surface.id}")
IO.puts("Components: #{A2UI.Surface.component_count(surface)}")
IO.puts("Root: #{surface.root_component_id}")
IO.puts("Data model keys: #{surface.data |> Map.keys() |> Enum.join(", ")}")
IO.puts("")

# Encode and pretty-print the v0.9 message array
json = A2UI.Encoder.encode_surface(surface)
messages = Jason.decode!(json)

Enum.each(messages, fn msg ->
  type = msg |> Map.keys() |> Enum.find(&(&1 != "version"))
  IO.puts("--- #{type} (#{msg["version"]}) ---")
  IO.puts(Jason.encode!(msg, pretty: true))
  IO.puts("")
end)

# Demonstrate decoding an incoming v0.9 action
IO.puts("=== Decoding incoming action ===\n")

incoming = Jason.encode!([%{
  "action" => %{
    "event" => %{
      "name" => "restart_service",
      "context" => %{"confirmed" => true}
    },
    "surfaceId" => "app-status"
  }
}])

IO.puts("Incoming JSON: #{incoming}\n")

case A2UI.Decoder.decode(incoming) do
  {:ok, [{:action, action, metadata}]} ->
    IO.puts("Decoded action: #{action.name}")
    IO.puts("Context: #{inspect(action.context)}")
    IO.puts("Surface ID: #{metadata.surface_id}")
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== A2UI spec version: #{A2UI.spec_version()} ===")
