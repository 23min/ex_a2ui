# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/) and uses
[Keep a Changelog](https://keepachangelog.com/) format.

## [0.5.0] - 2026-02-12

### Added

- **All 14 standard function helpers** — `numeric/1`, `email/1`, `format_number/1`, `format_currency/2`, `format_date/2`, `pluralize/3`, `fn_and/1`, `fn_or/1`, `fn_not/1` on both `FunctionCall` and `Builder` (was 5, now 14)
- **Client error messages** — `A2UI.Error` struct, decoder support for `error` messages from clients (`VALIDATION_FAILED`, generic errors)
- **`handle_error/2` callback** — optional callback on `SurfaceProvider` for reacting to client-reported errors
- **SSE transport adapter** — `A2UI.SSE` provides Server-Sent Events at `GET /sse` for push-only scenarios (dashboards, monitoring)
- **Custom component catalog** — `A2UI.Catalog` for registering and validating custom component types with property specs
- `Builder.catalog_id/2` — accepts string or `%Catalog{}` struct

### Changed

- `A2UI.Endpoint` now routes `/sse` to SSE adapter alongside existing `/ws` WebSocket
- `A2UI.Decoder` handles both `action` and `error` message types
- `A2UI.Socket` routes decoded error messages to provider's `handle_error/2`
- 220 tests (was 162)

### Fixed

- `mix.exs` version corrected from `"0.3.0"` to `"0.5.0"` (was never bumped for v0.4.0)

## [0.4.0] - 2026-02-12

### Added

- **FunctionCall** — client-evaluated computed values (`formatString`, `openUrl`, `required`, `regex`, `length`)
- **TemplateChildList** — data-driven children from data arrays
- **CheckRule** — input validation rules with `required`, `max_length`, `regex` helpers
- **Theme** — surface theming (`primaryColor`, `iconUrl`, `agentDisplayName`)
- **sendDataModel flag** — tells client to include full data model with actions
- **Path-level data operations** — `push_data_path/4` and `delete_data_path/3` on Server
- Builder helpers for all new features

### Changed

- Debug renderer updated for FunctionCall display, path-level data ops, theme application, TemplateChildList
- 162 tests (was 100)

## [0.3.0] - 2026-02-12

### Breaking Changes

- **v0.9 wire format** — all encoder output now uses v0.9 message names and structure
  - `surfaceUpdate` → `updateComponents`
  - `dataModelUpdate` → `updateDataModel`
  - `beginRendering` → `createSurface`
  - `userAction` → `action` (with `event` envelope containing `name`, `context`, `surfaceId`, `sourceComponentId`, `timestamp`)
  - All messages include `"version": "v0.9"` field
  - All messages wrapped in JSON arrays
- **Component format** — properties moved to top level (flat format), component type is a string discriminator
  - v0.8: `{"id": "t", "component": {"Text": {"text": {"literalString": "hi"}}}}`
  - v0.9: `{"id": "t", "component": "Text", "text": "hi"}`
- **BoundValue encoding** — literal values are plain values (no `literalString` wrapper), path bindings use `{"path": "..."}`
- **`encode_surface/1`** — returns a single `String.t()` (JSON array) instead of `[String.t()]` (list of JSON strings)
- **Encoder function renames** — `surface_update/1` → `update_components/1`, `data_model_update/2` → `update_data_model/2`, `begin_rendering/2,3` → `create_surface/1`
- **Decoder return format** — `{:ok, {:user_action, action}}` → `{:ok, [{:action, action, metadata}]}`
- Renamed `:multiple_choice` component type → `:choice_picker`

### Added

- `:audio_player` component type (18 standard types total)
- `catalog_id` field on `A2UI.Surface` struct
- Decoder extracts metadata from action envelope (`surface_id`, `source_component_id`, `timestamp`)
- Decoder accepts both JSON arrays and single objects
- `A2UI.spec_version/0` now returns `"v0.9"`

### Changed

- Debug renderer (`priv/static/index.html`) updated for v0.9 message format
- Demo script (`demo.exs`) updated for v0.9 API
- 100 tests (was 95)

## [0.2.0] - 2026-02-09

### Added

- **Server-initiated push updates** — `A2UI.Server.push_data/3` and `A2UI.Server.push_surface/2` broadcast data model or full surface updates to all connected clients
- `A2UI.Server.broadcast/3` — send arbitrary messages to all socket processes for a given surface
- `A2UI.Server.broadcast_all/2` — send arbitrary messages to all socket processes for a provider, regardless of surface ID
- Push functions accept `provider:` option for ergonomic registry resolution (e.g., `push_data("id", data, provider: MyProvider)`)
- `handle_info/2` optional callback on `SurfaceProvider` — react to timers, PubSub messages, GenServer casts, or any external event
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

[0.5.0]: https://github.com/23min/ex_a2ui/releases/tag/v0.5.0
[0.4.0]: https://github.com/23min/ex_a2ui/releases/tag/v0.4.0
[0.3.0]: https://github.com/23min/ex_a2ui/releases/tag/v0.3.0
[0.2.0]: https://github.com/23min/ex_a2ui/releases/tag/v0.2.0
[0.1.0]: https://github.com/23min/ex_a2ui/releases/tag/v0.1.0
[0.0.1]: https://github.com/23min/ex_a2ui/releases/tag/v0.0.1
