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

**Surface** — A canvas holding a flat list of components. Each surface has an ID and can be independently created, updated, or deleted.

**Component** — A UI element (Text, Button, Card, etc.) with a unique ID and type-specific properties. Components are organized as a flat adjacency list, not a nested tree. Parent-child relationships are expressed via `children` property references.

**BoundValue** — A value that can be a literal, a data model path (JSON Pointer), or both. Enables reactive binding: when the data model changes, bound components update automatically.

**Action** — A user interaction event (button click, form submit) that flows from the client back to the server, optionally carrying context resolved from the data model.

**DataModel** — Key-value state store (JSON Pointer paths → values) that components bind to. Updates to the data model trigger reactive UI updates without regenerating components.

### Why flat component lists?

A2UI uses flat adjacency lists instead of nested trees for three reasons:

1. **LLM-friendly** — LLMs are better at generating flat JSON lists than deeply nested structures. Incremental generation (add one component at a time) is natural with flat lists.
2. **Efficient streaming** — Add, modify, or remove individual components by ID without rebuilding the entire structure.
3. **Simple diffing** — Compare components by ID rather than tree position.

### Module structure

```
lib/a2ui/
  component.ex     — Component struct + standard type catalog
  surface.ex       — Surface struct + manipulation functions
  bound_value.ex   — Data binding (literal, path, or both)
  action.ex        — User action struct
  encoder.ex       — Elixir structs → A2UI JSON wire format
  decoder.ex       — Incoming JSON (userAction) → Elixir structs
  builder.ex       — Pipe-friendly convenience API for building surfaces
```

Future modules (not yet implemented):

```
lib/a2ui/
  server.ex        — Bandit HTTP + WebSocket endpoint
  socket.ex        — WebSock handler for A2UI message flow
  static.ex        — Plug for serving client-side renderer assets
  catalog.ex       — Custom component type registration
  data_model.ex    — JSON Pointer resolution and data store
```

### API layers

The library provides two layers. Users choose based on their needs:

**Layer 1: Structs** — Direct 1:1 mapping to the A2UI JSON spec. Full control, no magic. Code generators and advanced use cases.

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

A **DSL layer** (macro-based) is intentionally deferred. The Elixir community generally prefers explicit functions over macros, and the builder API is sufficient. A DSL will only be added if real-world usage demonstrates clear demand.

## Dependencies

### Current (v0.0.x — protocol types + encoder)

```elixir
{:jason, "~> 1.4"}  # JSON encoding/decoding
```

### Planned (v0.1.0 — server)

```elixir
{:bandit, "~> 1.0"}   # HTTP server (pure Elixir, by the creator of Plug)
{:websock, "~> 0.5"}  # WebSocket behavior
{:plug, "~> 1.15"}    # Static file serving
{:jason, "~> 1.4"}    # JSON encoding/decoding
```

No Phoenix. No Ecto. No LiveView.

### Optional integrations

- **phoenix_pubsub** — For broadcasting state changes to connected A2UI clients. Works standalone (does not require Phoenix).
- Custom renderer JS — Cytoscape.js, D3.js, or other client-side libraries for domain-specific visualization components.

## Development plan

### v0.0.1 — Protocol types and encoder (current)

Claim the namespace. Establish the foundation.

- Core structs: `Component`, `Surface`, `BoundValue`, `Action`
- `Encoder` — Elixir structs → valid A2UI JSON messages
- `Decoder` — incoming `userAction` JSON → Elixir structs
- `Builder` — pipe-friendly convenience API
- Tests validating JSON output against A2UI spec
- Published to Hex

**Scope boundary:** No server, no WebSocket, no HTML. Pure data types and encoding.

### v0.1.0 — WebSocket server

Make it usable: serve A2UI surfaces over WebSocket from any BEAM app.

- `A2UI.Server` — Bandit-based HTTP + WebSocket endpoint, embeddable in any OTP supervision tree
- `A2UI.Socket` — WebSock handler implementing the A2UI message flow
- `A2UI.Static` — Plug for serving a minimal HTML page with Google's Lit A2UI renderer
- `A2UI.SurfaceProvider` behaviour — applications implement this to define surfaces and handle actions
- Default renderer page in `priv/static/`
- Integration tests: start server, connect WebSocket, render surface, trigger action, receive response

**Scope boundary:** Standard A2UI components only. No custom component registration yet.

### v0.2.0 — Real-time updates and custom components

Make it reactive and extensible.

- `push_data/3` and `push_surface/2` for pushing updates to connected clients
- `A2UI.Catalog` — custom component type registration
- PubSub integration (optional, for broadcasting state changes)
- `A2UI.DataModel` — JSON Pointer resolution for data binding
- Streaming support (incremental surface building)
- Documentation for building custom client-side components (Web Components)

**Scope boundary:** Single-surface updates. No multi-surface routing or navigation.

### v0.3.0 — Production hardening

Based on real-world usage feedback.

- Multi-surface management (surface switching, lifecycle)
- Connection management (reconnection, state recovery)
- Client capability negotiation (`a2uiClientCapabilities`)
- Error handling and graceful degradation
- Performance optimization for large surfaces
- Telemetry integration for observability

### Future considerations

These are directions the library *might* go, depending on community needs:

- **AG-UI transport integration** — Support AG-UI as an alternative to raw WebSocket
- **Server-Sent Events transport** — For one-way push scenarios (dashboards, monitors)
- **Test helpers** — `A2UI.Test` module with assertion helpers for downstream applications
- **Mix tasks** — `mix a2ui.vendor` to download and vendor client-side renderer JS for offline use
- **LiveView bridge** — Optional adapter that lets LiveView applications render A2UI surfaces (using LiveView as transport instead of raw WebSocket). This would complement LiveView, not replace it.

## Design decisions and rationale

### Why Bandit over Cowboy?

Bandit is a pure Elixir HTTP server created by the maintainer of Plug. It's lighter than Cowboy, has first-class WebSocket support via WebSock, and doesn't bring in Erlang NIFs. For a library that values minimal dependencies, Bandit is the natural choice.

### Why not implement the client-side renderer?

A2UI separates concerns: the server produces declarative JSON, the client renders it. Google's Lit renderer (open source, Web Components-based) handles the client side. Building our own renderer would duplicate effort and diverge from the spec. The library ships a minimal HTML page that loads the Lit renderer — this is the thin bridge between server and client.

Custom domain-specific components (graph visualizations, code editors, etc.) are implemented as Web Components and registered in the client's component catalog. The library provides the registration mechanism, not the rendering.

### Why flat adjacency list, not nested component tree?

This is an A2UI spec decision, not ours. But it's a good one for BEAM applications:

- Elixir's pattern matching works naturally with flat lists of structs
- ETS tables can store components by ID for O(1) lookup
- Streaming updates (add/remove components) are simple list operations
- No deep nesting means no stack overflow risk with large surfaces

### Why two API layers (structs + builder) but not three (+ DSL)?

The Elixir community has shifted toward explicit, functional APIs and away from heavy macro usage. The builder API provides the convenience of a DSL (pipe-friendly, concise) without the downsides (compile-time complexity, harder debugging, IDE confusion). If real-world usage demonstrates clear demand for a macro DSL, it can be added as an optional layer without changing the struct or builder APIs.

### Why not support all A2UI features in v0.0.1?

The A2UI spec is v0.8 (public preview). It will change. By starting with the stable core (components, surfaces, encoding) and deferring unstable features (catalog negotiation, streaming, multi-surface lifecycle), we reduce the surface area exposed to spec changes. Each version adds features that are validated by real usage.

## A2UI spec compatibility

This library targets **A2UI v0.8** (public preview, January 2026).

The A2UI spec is evolving. Our versioning strategy:

- **Patch versions** (0.0.x) — bug fixes, no spec changes
- **Minor versions** (0.x.0) — new features, non-breaking spec updates
- **Major versions** (x.0.0) — breaking spec changes (e.g., A2UI v0.9 → v1.0)

The current spec version is exposed via `A2UI.spec_version/0`.

## Risks and mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| A2UI spec instability (v0.8) | Medium | Isolate spec mapping in encoder/decoder; core concepts (components, surfaces, actions) are stable |
| Small initial audience | Low | Library is useful to its author first; community is a bonus |
| API design wrong on first try | Medium | Ship early (0.0.x); iterate based on real usage before 1.0 |
| Lit renderer CDN dependency | Low | Document self-hosting; add `mix a2ui.vendor` in v0.2+ |
| Scope creep | Medium | Hard boundaries per version; reject features that belong in application code |
| Maintenance burden | Medium | Keep scope minimal; 4 deps max; no framework ambitions |

## Contributing

This project is in early development. The API will change. Feedback on the builder API, encoder output, and struct design is welcome via GitHub issues.

## References

- [A2UI specification](https://a2ui.org/)
- [A2UI GitHub (Google)](https://github.com/google/A2UI)
- [A2UI Renderer Development Guide](https://a2ui.org/guides/renderer-development/)
- [A2UI Components & Structure](https://a2ui.org/concepts/components/)
- [A2UI Agent UI Ecosystem](https://a2ui.org/introduction/agent-ui-ecosystem/)
- [Bandit HTTP Server](https://github.com/mtrudel/bandit)
- [WebSock](https://github.com/mtrudel/websock)
