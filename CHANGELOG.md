# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/) and uses
[Keep a Changelog](https://keepachangelog.com/) format.

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

[0.1.0]: https://github.com/23min/ex_a2ui/releases/tag/v0.1.0
[0.0.1]: https://github.com/23min/ex_a2ui/releases/tag/v0.0.1
