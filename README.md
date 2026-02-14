# ex_a2ui

Lightweight Elixir library for Google's [A2UI](https://a2ui.org/) protocol. Serve interactive, agent-driven UI surfaces from any BEAM app via declarative JSON over WebSocket — no Phoenix or LiveView required.

**Status:** v0.6.0 — complete Builder (all 18 types), debug renderer, 5 demo providers, telemetry, graceful error handling. 232 tests. See [ROADMAP.md](ROADMAP.md) for the full plan.

**A2UI spec:** v0.9

## Why Elixir for A2UI?

A2UI is a protocol where servers produce declarative JSON describing UI, and clients render it natively. The BEAM VM is a natural fit:

- **One process per connection** — each WebSocket client gets an isolated, lightweight process with its own state. No shared mutable state, millions of concurrent connections.
- **Fault tolerance** — one client's surface crashes, others are unaffected. The supervisor restarts it.
- **Real-time push** — broadcasting state changes to connected clients is what the BEAM was built for.
- **AI agent UIs** — LLMs generate flat JSON component lists, Elixir manages the stateful conversation loop, clients render natively.

## When to use this vs Phoenix LiveView

| | Phoenix LiveView | ex_a2ui |
|--|-----------------|---------|
| Rendering | Server-rendered HTML diffs | Client-rendered native widgets from JSON |
| Clients | Browser only | Browser, Flutter, Angular, React — any A2UI renderer |
| Dependencies | ~12+ packages (full web framework) | ~4 packages (protocol library) |
| AI/LLM friendly | No (HTML templates) | Yes (flat JSON designed for LLM generation) |
| Maturity | Battle-tested, huge ecosystem | Early, A2UI spec is v0.9 |

**Use LiveView** for full web applications. **Use ex_a2ui** for:

- **AI agent interfaces** — an LLM generates interactive UI as structured JSON, not HTML
- **Lightweight BEAM app UIs** — add a dashboard or config panel to an existing OTP app without pulling in Phoenix
- **Cross-platform from one server** — same Elixir backend serves browser (Lit), mobile (Flutter), desktop (Angular)

## Installation

```elixir
def deps do
  [
    {:ex_a2ui, "~> 0.6.0"}
  ]
end
```

## Quick start

Define a surface provider:

```elixir
defmodule MyApp.DashboardProvider do
  @behaviour A2UI.SurfaceProvider

  alias A2UI.Builder, as: UI

  @impl true
  def init(_opts), do: {:ok, %{count: 0}}

  @impl true
  def surface(state) do
    UI.surface("dashboard")
    |> UI.text("count", "Count: #{state.count}")
    |> UI.button("inc", "Increment", action: "increment")
    |> UI.card("main", children: ["count", "inc"])
    |> UI.root("main")
  end

  @impl true
  def handle_action(%A2UI.Action{name: "increment"}, state) do
    new_state = %{state | count: state.count + 1}
    {:reply, surface(new_state), new_state}
  end

  def handle_action(_action, state), do: {:noreply, state}
end
```

Start the server:

```elixir
# In your supervision tree:
children = [
  {A2UI.Server, provider: MyApp.DashboardProvider, port: 4000}
]
```

Open `http://localhost:4000` — the built-in debug renderer shows your surface and a message log.

## Try the demo

```bash
git clone https://github.com/23min/ex_a2ui.git
cd ex_a2ui
mix deps.get
mix run demo_server.exs
# Open http://localhost:4000
```

5 demo providers are available via query param:

- `http://localhost:4000/?demo=gallery` — Component Gallery (all 18 types, default)
- `http://localhost:4000/?demo=binding` — Data Binding (reactive updates)
- `http://localhost:4000/?demo=form` — Form Validation (CheckRule)
- `http://localhost:4000/?demo=push` — Push Streaming (live metrics)
- `http://localhost:4000/?demo=custom` — Custom Components (Catalog)

## What is A2UI?

A2UI (Agent-to-User Interface) is a Google protocol where AI agents generate interactive UI as declarative JSON. Instead of returning text or HTML, an agent describes UI components (buttons, cards, text fields) and the client renders them natively. User interactions flow back to the agent, creating a bidirectional loop.

```
Elixir app (server)          Browser/Mobile (client)
─────────────────           ─────────────────────
Build Surface structs  ──→  Receive JSON
Encode to A2UI JSON    ──→  Render native widgets
                       ←──  Send action JSON
Decode, update state   ──→  Receive updated surface
```

## API layers

### Builder (recommended)

Pipe-friendly functions for building surfaces:

```elixir
alias A2UI.Builder, as: UI

UI.surface("status")
|> UI.text("title", "Hello!")
|> UI.button("go", "Click Me", action: "do_thing")
|> UI.card("container", children: ["title", "go"])
```

### Structs (full control)

Direct protocol types for advanced use cases:

```elixir
%A2UI.Surface{
  id: "status",
  components: [
    %A2UI.Component{
      id: "title",
      type: :text,
      properties: %{text: %A2UI.BoundValue{literal: "Hello!"}}
    }
  ]
}
```

Both layers produce the same structs. Use whichever fits your style.

## Standard components

| Category | Types |
|----------|-------|
| Layout | `:row`, `:column`, `:list` |
| Display | `:text`, `:image`, `:icon`, `:video`, `:divider` |
| Interactive | `:button`, `:text_field`, `:checkbox`, `:date_time_input`, `:slider`, `:choice_picker` |
| Media | `:audio_player` |
| Container | `:card`, `:tabs`, `:modal` |

Custom components are supported via `Builder.custom/4`:

```elixir
UI.custom(surface, :my_chart, "chart-1", data: bind("/chart/data"))
```

## Data binding

Components bind to a data model using JSON Pointer paths:

```elixir
# Bind a text component to a data model path
UI.text(surface, "name", bind: "/user/name")

# Set the data model value
|> UI.data("/user/name", "Alice")
```

When the data model updates, bound components update automatically.

## Project structure

```
lib/
  a2ui.ex                  # Public API, spec version
  a2ui/
    component.ex           # Component struct + 18 standard types
    surface.ex             # Surface (flat component list + data model)
    bound_value.ex         # Data binding (literal or path)
    action.ex              # User interaction events
    function_call.ex       # Client-evaluated computed values (14 standard functions)
    template_child_list.ex # Data-driven children from data arrays
    check_rule.ex          # Input validation rules
    theme.ex               # Surface theming
    encoder.ex             # Elixir structs → A2UI v0.9 JSON wire format
    decoder.ex             # Incoming action/error JSON → Elixir structs
    error.ex               # Client error message struct
    catalog.ex             # Custom component type registry and validation
    builder.ex             # Pipe-friendly convenience API (all 18 types)
    surface_provider.ex    # Behaviour: init, surface, handle_action, handle_info, handle_error
    socket.ex              # WebSock handler (telemetry + graceful error handling)
    sse.ex                 # Server-Sent Events transport adapter (push-only)
    endpoint.ex            # Plug endpoint (HTTP + WS + SSE routing)
    supervisor.ex          # OTP Supervisor (Registry + Bandit)
    server.ex              # OTP supervision tree entry point, push API
priv/
  static/
    index.html             # Built-in debug renderer (all 18 component types)
demo/
  component_gallery.ex     # All 18 standard types
  data_binding.ex          # Reactive data binding demo
  form_validation.ex       # Form with CheckRule validation
  push_streaming.ex        # Timer-based live metrics
  custom_component.ex      # Catalog + custom components
```

## Dependencies

Runtime: `jason`, `bandit`, `websock_adapter`

That's it. No Phoenix, no Ecto, no LiveView.

## Development

```bash
git config core.hooksPath .githooks   # one-time setup
mix ci                                # format + compile + test (232 tests)
```

## License

MIT — see [LICENSE](LICENSE).
