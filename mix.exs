defmodule A2UI.MixProject do
  use Mix.Project

  @version "0.0.1"
  @source_url "https://github.com/23min/ex_a2ui"

  def project do
    [
      app: :ex_a2ui,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "A2UI",
      description:
        "Lightweight Elixir library for Google's A2UI protocol. " <>
          "Serve interactive, agent-driven UI surfaces from any BEAM app " <>
          "via declarative JSON over WebSocket — no Phoenix or LiveView required.",
      source_url: @source_url,
      homepage_url: @source_url,
      aliases: aliases()
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "A2UI Spec" => "https://a2ui.org/"
      },
      maintainers: ["23min"]
    ]
  end

  defp aliases do
    [
      ci: ["format --check-formatted", "compile --warnings-as-errors", "test"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "ROADMAP.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
