# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/) and uses
[Keep a Changelog](https://keepachangelog.com/) format.

## [0.2.0] - 2026-02-09

### Added

- **Server-initiated push updates** — `A2UI.Server.push_data/3` and `A2UI.Server.push_surface/2` broadcast data model or full surface updates to all connected clients
- `A2UI.Server.broadcast/3` — send arbitrary messages to all socket processes for a given surface
- `A2UI.Server.broadcast_all/2` — send arbitrary messages to all socket processes for a provider, regardless of surface ID
- Push functions accept `provider:` option for ergonomic registry resolution (e.g., `push_data("id", data, provider: MyProvider)`)
- `A2UI.SurfaceProvider.handle_info/2` — optional callback for reacting to timers, PubSub messages, GenServer casts, or any external event
- `A2UI.Supervisor` — OTP Supervisor that starts a Registry alongside Bandit for connection tracking and broadcast dispatch
- Socket processes auto-register in Registry on connect (under both surface ID and `:__all__` key), enabling push dispatch
- Demo server now demonstrates timer-based push (uptime counter updates every second)

### Changed

- `A2UI.Server.child_spec/1` now starts `A2UI.Supervisor` (which manages Registry + Bandit) instead of bare Bandit
- `A2UI.Supervisor` uses `:rest_for_one` strategy — if Registry crashes, Bandit restarts for clean recovery
- `A2UI.Endpoint` passes `:registry` through to Socket init args
- `A2UI.Socket` struct gains `:surface_id` and `:registry` fields

## [0.1.0] - 2026-02-09

### Added

- `A2UI.Server` — Bandit-based HTTP + WebSocket endpoint, embeddable in any OTP supervision tree
- `A2UI.Socket` — WebSock handler implementing the A2UI message flow
- `A2UI.Endpoint` — Plug endpoint for HTTP and WebSocket routing
- `A2UI.SurfaceProvider` behaviour — implement `init/1`, `surface/1`, and `handle_action/2` to define surfaces and handle user actions
- Default debug renderer page in `priv/static/index.html` — self-contained HTML/JS that renders A2UI surfaces and shows a message log
- Integration tests with real WebSocket connections (via `:gun`)
- Runnable demo server (`mix run demo_server.exs`)

### Dependencies

- Added `bandit` (~> 1.0) — pure Elixir HTTP server
- Added `websock_adapter` (~> 0.5) — WebSocket upgrade adapter
- Added `gun` (~> 2.1, test-only) — WebSocket client for integration tests

## [0.0.1] - 2026-02-08

### Added

- Core protocol structs: `Component`, `Surface`, `BoundValue`, `Action`
- `Encoder` — encode surfaces into A2UI JSON wire format (`surfaceUpdate`, `dataModelUpdate`, `beginRendering`, `deleteSurface`)
- `Decoder` — decode incoming `userAction` messages
- `Builder` — pipe-friendly API for constructing surfaces (`text`, `button`, `card`, `row`, `column`, `modal`, `checkbox`, `slider`, `text_field`, `image`, `divider`, `custom`)
- Support for all 17 standard A2UI component types
- Data binding via `BoundValue` (literal, path, or both)
- Custom component support via `Builder.custom/4`
- `A2UI.spec_version/0` reporting target A2UI spec version (v0.8)
- Runnable demo (`mix run demo.exs`)
- 43 tests

[0.2.0]: https://github.com/23min/ex_a2ui/releases/tag/v0.2.0
[0.1.0]: https://github.com/23min/ex_a2ui/releases/tag/v0.1.0
[0.0.1]: https://github.com/23min/ex_a2ui/releases/tag/v0.0.1
