# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/) and uses
[Keep a Changelog](https://keepachangelog.com/) format.

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

[0.0.1]: https://github.com/23min/ex_a2ui/releases/tag/v0.0.1
