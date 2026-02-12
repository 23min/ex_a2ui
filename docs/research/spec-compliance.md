# Spec Compliance: ex_a2ui vs A2UI Specification

## Context

ex_a2ui was built against A2UI **v0.8**. The spec is now at **v0.10** (active development), with **v0.9** being a major breaking rewrite. This document assesses where ex_a2ui stands, what changed in the spec, and what needs to happen for compliance.

Reference: https://github.com/google/A2UI/tree/main/specification
Blazor reference implementation: https://github.com/23min/a2ui-blazor (targets v0.9, tracks compliance in SPECIFICATION.md)

## Spec Version History

| Version | Status | Notes |
|---------|--------|-------|
| v0.8 | Closed/archived | What ex_a2ui targets. Dynamic-key component format. |
| v0.9 | Closed | **Major rewrite.** Renamed all messages. New component format. Modular schemas. Bidirectional data model. |
| v0.10 | Active | Current. Same structure as v0.9. Extension spec, evolution guide (TBD). |

**Bottom line:** v0.9 broke everything. The jump from v0.8 to v0.9 is not incremental — it's a rethink of the wire format.

## What Changed: v0.8 to v0.9

### Message Types (Server-to-Client)

| v0.8 (ex_a2ui today) | v0.9 | Notes |
|----------------------|------------|-------|
| `surfaceUpdate` | `updateComponents` | Renamed |
| `dataModelUpdate` | `updateDataModel` | Renamed, now supports path-level upsert/delete |
| `beginRendering` | `createSurface` | Renamed, now requires `catalogId` |
| `deleteSurface` | `deleteSurface` | Unchanged |

### Message Types (Client-to-Server)

| v0.8 (ex_a2ui today) | v0.9 | Notes |
|----------------------|------------|-------|
| `userAction` | `action` | Renamed, new envelope: `name`, `surfaceId`, `sourceComponentId`, `timestamp` (ISO 8601), `context` |
| *(none)* | `error` | **New.** Client reports errors: `VALIDATION_FAILED` (with `path`) or generic |

### Component Wire Format

**v0.8** (what ex_a2ui emits):
```json
{"id": "t1", "component": {"Text": {"text": {"literalString": "Hello"}}}}
```

**v0.9** (what spec expects):
```json
{"id": "t1", "component": "Text", "text": "Hello"}
```

Key changes:
- **No more nested dynamic key.** `component` is now a discriminator string, not a wrapper object.
- **Properties at top level** of the component object, not nested under the type key.
- **Literal values are plain values**, not `{"literalString": "..."}` wrappers.
- **DataBinding is `{"path": "/..."}` objects** — same as before, but without the literalString companion.

### Data Binding / Dynamic Types

v0.8 had `BoundValue` with `literalString`/`path`/both. v0.9 uses a cleaner `Dynamic*` type system:

| Dynamic Type | Accepts |
|-------------|---------|
| `DynamicString` | `"hello"` (plain string) or `{"path": "/json/pointer"}` or `FunctionCall` |
| `DynamicNumber` | `42` or `{"path": "..."}` or `FunctionCall` |
| `DynamicBoolean` | `true` or `{"path": "..."}` or `FunctionCall` |
| `DynamicStringList` | `["a","b"]` or `{"path": "..."}` or `FunctionCall` |
| `DynamicValue` | Any of the above |

**No more "both" mode** (literal + path simultaneously). The `formatString` function with `${/path}` interpolation replaces that use case.

### Actions

v0.8 action:
```json
{"name": "submit", "context": {"key": "value"}}
```

v0.9 action has two variants:

**Server event** (sends to server):
```json
{"event": {"name": "submit", "context": {"key": <DynamicValue>}}}
```

**Local function** (runs on client):
```json
{"functionCall": {"call": "openUrl", "args": {"url": "https://..."}}}
```

### New Concepts (not in v0.8 at all)

| Feature | What it is |
|---------|-----------|
| **Version field** | Every message MUST include `"version": "v0.10"` |
| **Message arrays** | Messages always sent as JSON arrays, never individual objects |
| **MIME type** | `application/json+a2ui` for transport metadata |
| **catalogId** | `createSurface` must specify which component catalog to use |
| **sendDataModel** | Flag on `createSurface` — client sends full data model back with actions |
| **Capability negotiation** | Client declares `supportedCatalogIds` via metadata |
| **FunctionCall** | Computed values: `{"call": "fn", "args": {...}, "returnType": "string"}` |
| **Standard functions (14)** | Validation: required, regex, length, numeric, email. Formatting: formatString, formatNumber, formatCurrency, formatDate, pluralize. Logic: and, or, not. Actions: openUrl. |
| **CheckRule** | Validation rules on input components: `{"condition": <DynamicBoolean>, "message": "..."}` |
| **Template ChildList** | Dynamic children from data: `{"path": "/items", "componentId": "item-template"}` |
| **Theme** | `primaryColor`, `iconUrl`, `agentDisplayName` on createSurface |
| **Two-way binding** | Input components write back to client data model; synced to server on action |
| **Root component** | Must have `id: "root"` (not arbitrary) |

### Component Renames

| v0.8 (ex_a2ui) | v0.9 |
|----------------|------------|
| `:multiple_choice` | `ChoicePicker` |

### Missing Components

| Component | Category | Status in ex_a2ui |
|-----------|----------|-------------------|
| `AudioPlayer` | Display | Missing entirely — not in type union or encoder |

## Current ex_a2ui Compliance Status

### What's Correct (structure-wise, needs format update)

- 16 of 17 standard component types present (missing AudioPlayer)
- Flat adjacency list model (matches spec concept)
- JSON Pointer paths for data binding
- Action with name + context
- Surface with components + data model + root
- Encoder/decoder architecture

### What's Wrong (v0.8 format, needs migration)

| Area | v0.8 (current) | v0.9 (target) | Scope |
|------|---------------|---------------------|-------|
| Message: surface update | `surfaceUpdate` | `updateComponents` | Rename |
| Message: data model | `dataModelUpdate` | `updateDataModel` | Rename + restructure (path-level ops) |
| Message: begin rendering | `beginRendering` | `createSurface` | Rename + add catalogId, theme, sendDataModel |
| Client message | `userAction` | `action` | Rename + new envelope fields |
| Component format | `{"component": {"Text": {...}}}` | `{"component": "Text", ...props}` | **Major restructure** |
| BoundValue | `{"literalString": "x"}` / `{"path": "..."}` | Plain literals / `{"path": "..."}` | Simplification |
| Action format | `{"name": "x"}` | `{"event": {"name": "x"}}` or `{"functionCall": {...}}` | Restructure |
| Version field | Not present | Required on every message | Add |
| Message framing | Individual JSON objects | Always arrays | Wrap |
| Root component ID | Any ID | Must be `"root"` | Convention change |

### What's Missing (new features needed)

| Feature | Effort | Priority |
|---------|--------|----------|
| AudioPlayer component type | Trivial | High (completeness) |
| ChoicePicker rename (from multiple_choice) | Trivial | High |
| Version field on all messages | Small | High (compliance) |
| Message array wrapping | Small | High (compliance) |
| catalogId on createSurface | Small | High |
| Client error message type | Small | Medium |
| Theme support | Small | Medium |
| sendDataModel flag | Medium | Medium |
| FunctionCall in Dynamic types | Medium | Medium |
| Template ChildList | Medium | Medium |
| CheckRule / validation | Medium | Medium |
| Standard functions (14) | Large | Lower (server-side lib may not need all) |
| Capability negotiation | Medium | Lower (transport-dependent) |
| Two-way binding protocol | Medium | Lower (client-side concern mostly) |

## Comparison with a2ui-blazor

The Blazor project (v0.4.0-preview) targets v0.9 and tracks compliance in SPECIFICATION.md. It has:

- All 4 server-to-client message types with v0.9 naming
- v0.9 client-to-server action envelope
- 17 components (13 fully v0.9-compliant, 4 with minor property name gaps)
- Data binding: literals, JSON Pointer, formatString interpolation
- 5 demo agents showcasing different patterns
- 115+ unit tests, 19 E2E browser tests

**ex_a2ui's gap relative to a2ui-blazor:**
The primary gap is the v0.8-to-v0.9 wire format migration. Once message names, component format, and value encoding are updated, the feature surface is comparable for a server-side library. The Blazor project's client-side features (rendering, two-way binding, function evaluation) are renderer concerns that don't apply to ex_a2ui's server role.

## Migration Strategy

The v0.8 → v0.9 migration touches every layer:

1. **Encoder** — the biggest change. Component format, message names, value encoding all change.
2. **Decoder** — new action envelope format, add error message type.
3. **BoundValue** — simplify to plain values + path objects. Remove literalString wrapping. Possibly rename to reflect Dynamic* terminology.
4. **Action** — split into event vs functionCall variants.
5. **Component** — add `:audio_player`, rename `:multiple_choice` to `:choice_picker`.
6. **Surface** — root component must use `id: "root"`. Add catalogId, theme, sendDataModel.
7. **Builder** — update to match new Surface/Component/Action shapes.
8. **Tests** — all encoder/decoder tests need updating for new wire format.
9. **Demo** — update to produce v0.9 compliant output.

**This is a breaking change.** Nobody is using the library yet, so we just change it. No backwards-compat ceremony.

## Decisions

1. **Target v0.9.** It's the latest closed spec. v0.10 is still in flux. Match what a2ui-blazor targets.

2. **Standard functions:** The server needs to *emit* FunctionCall values in component properties (e.g., a Button's action can be a `{"functionCall": {"call": "openUrl", ...}}`). The server does NOT need to *evaluate* functions — that's the client renderer's job. So ex_a2ui needs:
   - A `FunctionCall` struct that the encoder can serialize
   - The 14 standard function names as constants/documentation
   - Builder helpers for common patterns (e.g., `UI.open_url_action(url)`)
   - No function evaluation engine

3. **Transport options:** The spec is transport-agnostic. ex_a2ui should offer multiple transport options, not just WebSocket. The encoder already produces transport-independent JSON strings, so adding SSE or HTTP streaming adapters is straightforward. WebSocket remains the default for bidirectional communication, but SSE is natural for dashboard/monitoring use cases (server push only).

4. **MIME type / capability negotiation:** Deferred. Need to research what's idiomatic for Elixir libraries before deciding on the API shape.

5. **Breaking change strategy:** Just do it. No feature flags, no version negotiation. We're pre-1.0, nobody depends on us. Change the wire format, update all tests, ship it.

See ROADMAP.md for the implementation plan.
