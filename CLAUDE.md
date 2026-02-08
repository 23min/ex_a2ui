# ex_a2ui — Development Guide

## What is this?

Lightweight Elixir library for Google's A2UI (Agent-to-User Interface) protocol.
Encodes/decodes A2UI JSON wire format. No Phoenix, no LiveView — just structs and JSON.

**A2UI spec version:** v0.8 (public preview)

## Key Commands

```bash
mix ci                    # format check + compile (warnings-as-errors) + test
mix test                  # tests only
mix format                # auto-format
mix docs                  # generate ExDoc
mix run demo.exs          # runnable demo
```

## Architecture

- **Flat adjacency list** — components referenced by ID in a flat list, not nested trees. LLM-friendly, efficient for streaming.
- **BoundValue** — data binding via JSON Pointer paths (literal, path, or both).
- **Three API layers** — Structs (protocol types) → Builder (pipe-friendly) → DSL (deferred, only if demanded).
- **Minimal deps** — only `jason` at runtime. `ex_doc` dev-only.

## Design Decisions

- No Phoenix/LiveView: A2UI is client-rendered JSON, fundamentally incompatible with server-rendered HTML.
- No macros/DSL in v0.0.x: Builder API with pipes is idiomatic enough. DSL only if community demands it.
- Encoder outputs JSON strings (not maps): wire-ready, no double-encoding risk.
- Custom components via `{:custom, atom()}` type tuple, not a separate struct.
- Snake_case internally, camelCase on the wire (encoder handles conversion).

## Module Map

- `A2UI` — public API, `spec_version/0`
- `A2UI.Component` — struct + 17 standard types
- `A2UI.Surface` — flat component list + data model
- `A2UI.BoundValue` — literal/path/both data binding
- `A2UI.Action` — user interaction events
- `A2UI.Encoder` — structs → A2UI JSON wire format
- `A2UI.Decoder` — incoming userAction JSON → structs
- `A2UI.Builder` — pipe-friendly convenience API

## Current State

**v0.0.1** — core types, encoder, decoder, builder. 43 tests. No runtime (no WebSocket server).

## Next Steps

1. Add `@moduledoc`, `@doc`, `@spec` to all modules (ExDoc readiness)
2. v0.1.0 — WebSocket server (Bandit + WebSock + Plug)
3. v0.2.0 — SurfaceProvider behaviour, PubSub, live updates

## Pre-commit Hook

`.githooks/pre-commit` runs `mix ci`. Configured via `git config core.hooksPath .githooks`.

## Related

This library originated from LodeTime project research. It is standalone — no LodeTime dependency.
See `SESSION_CONTEXT.md` (gitignored, local-only) for full discussion context if present.
