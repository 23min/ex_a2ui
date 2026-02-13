# ex_a2ui Roadmap

## What is this project?

ex_a2ui is an Elixir implementation of Google's [A2UI](https://a2ui.org/) (Agent-to-User Interface) protocol. It lets any BEAM/OTP application serve interactive, agent-driven UI surfaces using declarative JSON — without Phoenix, LiveView, or heavyweight web framework dependencies.

## Why does this exist?

### The gap

A2UI is a protocol where AI agents generate interactive UI as structured JSON. Client-side renderers (Lit, Angular, Flutter) turn that JSON into native widgets. The agent doesn't produce HTML — it declares *what* to show, and the renderer decides *how*.

As of February 2026, official A2UI renderers exist for Lit (Web Components), Angular, Flutter, and React (in progress). **No Elixir implementation exists.** This is a missed opportunity because the BEAM's strengths — real-time communication, concurrent connections, fault-tolerant long-running processes — are exactly what an A2UI server needs.

### Why not Phoenix/LiveView?

Phoenix LiveView is excellent for server-rendered HTML applications. But it's a full web framework with significant dependency weight (Phoenix, phoenix_html, phoenix_live_view, floki, plug_cowboy, telemetry, etc.).

Many BEAM applications need to surface a simple UI — a status dashboard, a configuration panel, an interactive report — but don't want or need the full Phoenix stack. A2UI provides a different architectural model:

| Phoenix LiveView | ex_a2ui |
|-----------------|---------|
| Server renders HTML, pushes DOM diffs | Server pushes JSON, client renders natively |
| Rich Elixir template system (HEEx) | Declarative component model (no templates) |
| ~12+ dependencies | ~4 dependencies |
| Full web framework capabilities | Protocol implementation only |

These are different tools for different problems. LiveView is the right choice for full web applications. ex_a2ui is the right choice for lightweight agent-driven surfaces where the UI is generated programmatically from application state.

### Where A2UI fits in the protocol stack

```
A2A  (Agent-to-Agent)     — agent coordination
MCP  (Model Context)      — agent-to-tools
AG-UI (runtime transport)  — bidirectional agent-to-UI channel
A2UI  (declarative spec)   — what UI to render
```

A2UI defines *what* UI to render. AG-UI defines *how* to transport it. MCP defines *what tools* the agent has. They are complementary layers. An agent can use MCP to query application state, then respond with A2UI components that visualize that state.

## Architecture

### Core concepts

**Surface** — A canvas holding a flat list of components. Each surface has an ID, a catalog reference, and can be independently created, updated, or deleted.

**Component** — A UI element (Text, Button, Card, etc.) with a unique ID and type-specific properties. Components are organized as a flat adjacency list, not a nested tree. Parent-child relationships are expressed via `children` property references.

**Dynamic Values** — Property values that can be literals, data model bindings (JSON Pointer paths), or function calls. Enables reactive binding: when the data model changes, bound components update automatically.

**Action** — Either a server event (flows back to the server with context) or a local function call (executed on the client). Triggered by user interaction with actionable components.

**DataModel** — JSON state that components bind to via JSON Pointer paths. Updates to the data model trigger reactive UI updates without regenerating components.

### Why flat component lists?

A2UI uses flat adjacency lists instead of nested trees for three reasons:

1. **LLM-friendly** — LLMs are better at generating flat JSON lists than deeply nested structures. Incremental generation (add one component at a time) is natural with flat lists.
2. **Efficient streaming** — Add, modify, or remove individual components by ID without rebuilding the entire structure.
3. **Simple diffing** — Compare components by ID rather than tree position.

### Module structure

```
lib/a2ui/
  component.ex         — Component struct + 18 standard types
  surface.ex           — Surface struct (flat component list + data model)
  bound_value.ex       — Data binding (literal, path, or both)
  action.ex            — User action struct
  encoder.ex           — Elixir structs → A2UI JSON wire format
  decoder.ex           — Incoming JSON → Elixir structs
  builder.ex           — Pipe-friendly convenience API
  server.ex            — Bandit HTTP + WebSocket endpoint, push API
  socket.ex            — WebSock handler for A2UI message flow
  endpoint.ex          — Plug endpoint (HTTP + WS routing)
  surface_provider.ex  — Behaviour for defining surfaces
  supervisor.ex        — OTP Supervisor (Registry + Bandit)
```

### API layers

The library provides two layers. Users choose based on their needs:

**Layer 1: Structs** — Direct 1:1 mapping to the A2UI JSON spec. Full control, no magic.

```elixir
%A2UI.Surface{
  id: "status",
  components: [
    %A2UI.Component{
      id: "title",
      type: :text,
      properties: %{text: %A2UI.BoundValue{literal: "Hello"}}
    }
  ]
}
```

**Layer 2: Builder** — Pipe-friendly functions that reduce boilerplate. Recommended for most use cases.

```elixir
alias A2UI.Builder, as: UI

UI.surface("status")
|> UI.text("title", "Hello")
|> UI.text("health", bind: "/health")
|> UI.button("check", "Run Check", action: "run_check")
|> UI.card("main", children: ["title", "health", "check"])
|> UI.data("/health", "operational")
|> UI.root("main")
```

Both layers produce the same structs. The encoder doesn't care which layer created them.

## Spec Target

**A2UI v0.9** — the latest closed specification version.

See `docs/research/spec-compliance.md` in the repository for the full gap analysis against the spec and comparison with the [a2ui-blazor](https://github.com/23min/a2ui-blazor) reference implementation.

## Development Plan

### v0.0.1 — Protocol types and encoder ✅

Core structs, encoder, decoder, builder. 43 tests.

### v0.1.0 — WebSocket server ✅

Bandit-based HTTP + WebSocket endpoint. SurfaceProvider behaviour. Debug renderer. Integration tests. 67 tests.

### v0.2.0 — Push updates ✅

Server-initiated push (push_data, push_surface, broadcast, broadcast_all). OTP Supervisor with Registry. Optional handle_info/2 callback. 95 tests.

### v0.3.0 — v0.9 Wire Format Migration ✅

v0.9-compliant JSON wire format. Breaking changes to encoder/decoder output. 100 tests.

**Message renames:** `surfaceUpdate` → `updateComponents`, `dataModelUpdate` → `updateDataModel`, `beginRendering` → `createSurface`, `userAction` → `action` (with event envelope). All messages include `"version": "v0.9"` and are wrapped in JSON arrays.

**Component format change:** Properties moved to top level (flat format), literal values are plain values (no wrapper objects), component type is a string discriminator.

**Struct/type changes:** Added `:audio_player`, renamed `:multiple_choice` → `:choice_picker` (18 standard types). Surface gained `catalog_id` field. `encode_surface/1` returns single JSON string (was list of strings).

### v0.4.0 — v0.9 Data Features ✅

FunctionCall, TemplateChildList, CheckRule, Theme, sendDataModel, path-level data operations. Builder helpers for all new types. 162 tests.

### v0.5.0 — Protocol Completeness & Transport Options ✅

All 14 standard function helpers. Client error messages with `handle_error/2` callback. SSE transport adapter. Custom component catalog with validation. 220 tests.

### v0.6.0 — Demo Parity & Production Hardening ✅

Complete Builder helpers (all 18 types). Complete debug renderer (all 18 types). 5 demo providers. Telemetry instrumentation. Graceful error handling. 232 tests.

Deferred to future: Multi-surface management, reconnection/state recovery, performance optimization.

### Future Considerations

- **AG-UI transport integration** — Support AG-UI as an alternative transport
- **Capability negotiation** — Client declares supportedCatalogIds (deferred: need to research idiomatic Elixir patterns)
- **Test helpers** — `A2UI.Test` module with assertion helpers for downstream applications
- **Mix tasks** — `mix a2ui.vendor` to download and vendor client-side renderer JS
- **LiveView bridge** — Optional adapter that lets LiveView applications render A2UI surfaces

## Dependencies

### Current (v0.6.0)

```elixir
{:jason, "~> 1.4"}            # JSON encoding/decoding
{:bandit, "~> 1.0"}           # HTTP server (pure Elixir)
{:websock_adapter, "~> 0.5"}  # WebSocket upgrade adapter
```

Test-only: `{:gun, "~> 2.1"}`. Dev-only: `{:ex_doc, "~> 0.31"}`.

No Phoenix. No Ecto. No LiveView.

## Design Decisions

### Why Bandit over Cowboy?

Bandit is a pure Elixir HTTP server created by the maintainer of Plug. It's lighter than Cowboy, has first-class WebSocket support via WebSock, and doesn't bring in Erlang NIFs. For a library that values minimal dependencies, Bandit is the natural choice.

### Why not implement the client-side renderer?

A2UI separates concerns: the server produces declarative JSON, the client renders it. Google's Lit renderer (open source, Web Components-based) handles the client side. Building our own renderer would duplicate effort and diverge from the spec. The library ships a minimal HTML page that loads the Lit renderer — this is the thin bridge between server and client.

### Why flat adjacency list, not nested component tree?

This is an A2UI spec decision, not ours. But it's a good one for BEAM applications:

- Elixir's pattern matching works naturally with flat lists of structs
- ETS tables can store components by ID for O(1) lookup
- Streaming updates (add/remove components) are simple list operations
- No deep nesting means no stack overflow risk with large surfaces

### Why two API layers (structs + builder) but not three (+ DSL)?

The Elixir community has shifted toward explicit, functional APIs and away from heavy macro usage. The builder API provides the convenience of a DSL (pipe-friendly, concise) without the downsides (compile-time complexity, harder debugging, IDE confusion). A DSL will only be added if real-world usage demonstrates clear demand.

## References

- [A2UI specification](https://github.com/google/A2UI/tree/main/specification)
- [A2UI website](https://a2ui.org/)
- [a2ui-blazor reference implementation](https://github.com/23min/a2ui-blazor)
- [Bandit HTTP Server](https://github.com/mtrudel/bandit)
- [WebSock](https://github.com/mtrudel/websock)
