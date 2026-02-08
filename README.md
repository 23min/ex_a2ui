# ex_a2ui

Lightweight Elixir library for Google's [A2UI](https://a2ui.org/) protocol. Serve interactive, agent-driven UI surfaces from any BEAM app via declarative JSON over WebSocket — no Phoenix or LiveView required.

**Status:** Early development (v0.0.1). API will change. See [ROADMAP.md](ROADMAP.md) for the full plan.

**A2UI spec:** v0.8 (public preview)

## Installation

```elixir
def deps do
  [
    {:ex_a2ui, "~> 0.0.1"}
  ]
end
```

## Quick start

```elixir
alias A2UI.Builder, as: UI

# Build a surface
surface =
  UI.surface("my-dashboard")
  |> UI.text("title", "System Status")
  |> UI.text("health", bind: "/system/health")
  |> UI.button("refresh", "Refresh", action: "refresh")
  |> UI.card("main", children: ["title", "health", "refresh"])
  |> UI.data("/system/health", "operational")
  |> UI.root("main")

# Encode to A2UI JSON messages
messages = A2UI.Encoder.encode_surface(surface)
# => ["{\"surfaceUpdate\":{...}}", "{\"dataModelUpdate\":{...}}", "{\"beginRendering\":{...}}"]
```

## What is A2UI?

A2UI (Agent-to-User Interface) is a protocol where AI agents generate interactive UI as declarative JSON. Instead of returning text or HTML, an agent describes UI components (buttons, cards, text fields) and the client renders them natively. User interactions flow back to the agent, creating a bidirectional exploration loop.

This library provides the Elixir server-side implementation: types, encoding, and (soon) a WebSocket server.

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
| Interactive | `:button`, `:text_field`, `:checkbox`, `:date_time_input`, `:slider`, `:multiple_choice` |
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

When the data model updates, bound components update automatically (once the WebSocket server is implemented in v0.1.0).

## Try it

A runnable demo is included that builds a multi-component dashboard surface and pretty-prints the A2UI JSON output:

```bash
git clone https://github.com/23min/ex_a2ui.git
cd ex_a2ui
mix deps.get
mix run demo.exs
```

This builds a 14-component surface (text, buttons, checkbox, layout containers, card) with data bindings, encodes it to the three A2UI message types (`surfaceUpdate`, `dataModelUpdate`, `beginRendering`), and demonstrates decoding an incoming `userAction`. Run `mix test` to verify the full suite (43 tests).

## Project structure

```
lib/
  a2ui.ex                  # Public API, spec version
  a2ui/
    component.ex           # Component struct + 17 standard types
    surface.ex             # Surface (flat component list + data model)
    bound_value.ex         # Data binding (literal, path, or both)
    action.ex              # User interaction events
    encoder.ex             # Elixir structs → A2UI JSON wire format
    decoder.ex             # Incoming userAction JSON → Elixir structs
    builder.ex             # Pipe-friendly convenience API
test/
  a2ui/
    builder_test.exs       # Builder API tests
    component_test.exs     # Component type catalog tests
    encoder_test.exs       # JSON output validation
    decoder_test.exs       # Incoming message parsing
demo.exs                   # Runnable demo (mix run demo.exs)
ROADMAP.md                 # Architecture, rationale, development plan
```

## Current scope (v0.0.1)

- Core structs: `Component`, `Surface`, `BoundValue`, `Action`
- `Encoder` — structs → A2UI JSON messages
- `Decoder` — incoming `userAction` JSON → structs
- `Builder` — pipe-friendly surface construction

**Not yet implemented:** WebSocket server, static file serving, PubSub integration, custom component catalog. See [ROADMAP.md](ROADMAP.md).

## Dependencies

```
jason ~> 1.4
```

That's it. The WebSocket server (v0.1.0) will add `bandit`, `websock`, and `plug`.

## License

MIT — see [LICENSE](LICENSE).
