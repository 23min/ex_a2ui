alias A2UI.Builder, as: UI
alias A2UI.{FunctionCall, CheckRule, BoundValue}

IO.puts("=== ex_a2ui Demo (v0.4.0) ===\n")

# Build a dashboard surface with v0.4.0 features
surface =
  UI.surface("app-status")
  # Theme
  |> UI.theme(primary_color: "#2196F3", agent_display_name: "Dashboard Agent")
  |> UI.send_data_model(true)
  # Display with FunctionCall
  |> UI.text("title", "Application Dashboard")
  |> UI.text("greeting", FunctionCall.format_string("Hello ${/user/name}, welcome back!"))
  |> UI.text("health-label", "System Health:")
  |> UI.text("health-value", bind: "/system/health")
  |> UI.text("uptime-label", "Uptime:")
  |> UI.text("uptime-value", bind: "/system/uptime")
  # Buttons
  |> UI.button("refresh", "Refresh Status", action: "refresh")
  |> UI.button("restart", "Restart Service", action: "restart_service")
  |> UI.checkbox("auto-refresh", label: "Auto-refresh", bind: "/settings/auto_refresh")
  # Form with validation (CheckRule)
  |> UI.text_field("name-field",
    bind: "/form/name",
    placeholder: "Your name",
    checks: [
      UI.required_check("/form/name"),
      UI.max_length_check("/form/name", 50, "Name must be 50 chars or less")
    ]
  )
  |> UI.text_field("email-field",
    bind: "/form/email",
    placeholder: "Email",
    checks: [
      UI.required_check("/form/email", "Email is required"),
      UI.regex_check("/form/email", "^[^@]+@[^@]+$", "Invalid email format")
    ]
  )
  # Template children — message list driven by data model
  |> UI.text("msg-tpl", bind: "/text")
  |> UI.column("messages", children: UI.template_children("/messages", "msg-tpl"))
  # Layout
  |> UI.divider("sep1")
  |> UI.row("health-row", children: ["health-label", "health-value"])
  |> UI.row("uptime-row", children: ["uptime-label", "uptime-value"])
  |> UI.row("actions", children: ["refresh", "restart", "auto-refresh"])
  |> UI.column("form", children: ["name-field", "email-field"])
  |> UI.column("body",
    children: ["greeting", "health-row", "uptime-row", "sep1", "actions", "form", "messages"]
  )
  |> UI.card("main", children: ["title", "body"], title: "Status")
  # Data model
  |> UI.data("/user/name", "Developer")
  |> UI.data("/system/health", "operational")
  |> UI.data("/system/uptime", "3d 14h 22m")
  |> UI.data("/settings/auto_refresh", true)
  |> UI.data("/messages", [%{"text" => "System started"}, %{"text" => "Health check passed"}])
  |> UI.root("main")

IO.puts("Surface: #{surface.id}")
IO.puts("Components: #{A2UI.Surface.component_count(surface)}")
IO.puts("Root: #{surface.root_component_id}")
IO.puts("Theme: #{inspect(surface.theme)}")
IO.puts("sendDataModel: #{surface.send_data_model}")
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

# Demonstrate path-level data operations
IO.puts("=== Path-level data model operations ===\n")

upsert = A2UI.Encoder.update_data_model_path("app-status", "/system/uptime", "4d 2h 15m")
IO.puts("Path upsert:")
IO.puts(Jason.encode!(Jason.decode!(upsert), pretty: true))
IO.puts("")

delete = A2UI.Encoder.delete_data_model_path("app-status", "/temp/stale_data")
IO.puts("Path delete:")
IO.puts(Jason.encode!(Jason.decode!(delete), pretty: true))
IO.puts("")

# Demonstrate decoding an incoming v0.9 action
IO.puts("=== Decoding incoming action ===\n")

incoming =
  Jason.encode!([
    %{
      "action" => %{
        "event" => %{
          "name" => "restart_service",
          "context" => %{"confirmed" => true}
        },
        "surfaceId" => "app-status"
      }
    }
  ])

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
