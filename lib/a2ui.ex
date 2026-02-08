defmodule A2UI do
  @moduledoc """
  Lightweight Elixir implementation of Google's A2UI (Agent-to-User Interface) protocol.

  A2UI lets agents generate interactive UI surfaces as declarative JSON.
  This library provides the Elixir types, encoder, and builder for producing
  valid A2UI messages — without Phoenix, LiveView, or heavyweight dependencies.

  ## Quick start

      alias A2UI.Builder, as: UI

      surface =
        UI.surface("my-status")
        |> UI.text("title", "System Status")
        |> UI.text("health", bind: "/system/health")
        |> UI.button("check", "Run Check", action: "run_check")
        |> UI.card("main", children: ["title", "health", "check"])

      # Encode to A2UI JSON messages
      A2UI.Encoder.surface_update(surface)

  ## API layers

  - **Structs** (`A2UI.Component`, `A2UI.Surface`, etc.) — direct protocol types
  - **Builder** (`A2UI.Builder`) — pipe-friendly convenience functions
  - **Encoder** (`A2UI.Encoder`) — structs to A2UI JSON

  ## A2UI spec version

  This library targets A2UI v0.8 (public preview).
  """

  @a2ui_spec_version "0.8"

  @doc "Returns the A2UI specification version this library targets."
  @spec spec_version() :: String.t()
  def spec_version, do: @a2ui_spec_version
end
