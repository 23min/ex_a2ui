defmodule Demo.CustomComponent do
  @behaviour A2UI.SurfaceProvider

  alias A2UI.Builder, as: UI

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def surface(_state) do
    catalog = A2UI.Catalog.new("demo-catalog-v1")
    |> A2UI.Catalog.register("sparkline",
      description: "Inline sparkline chart",
      properties: [:data, :color, :height],
      required: [:data]
    )
    |> A2UI.Catalog.register("badge",
      description: "Status badge",
      properties: [:text, :variant]
    )

    UI.surface("custom-component")
    |> UI.theme(agent_display_name: "Custom Component Demo")
    |> UI.catalog_id(catalog)
    # Custom sparkline
    |> UI.custom(:sparkline, "spark1", data: [3, 7, 2, 9, 4, 6, 1], color: "#e94560", height: 40)
    |> UI.custom(:sparkline, "spark2", data: [1, 2, 4, 8, 16, 32], color: "#4ecca3", height: 40)
    # Custom badge
    |> UI.custom(:badge, "badge1", text: "Online", variant: "success")
    |> UI.custom(:badge, "badge2", text: "Maintenance", variant: "warning")
    # Standard components alongside custom
    |> UI.text("desc",
      "Custom components use {:custom, :type_name} and are registered in a Catalog. " <>
        "The client renderer is responsible for rendering them."
    )
    |> UI.row("sparks", children: ["spark1", "spark2"])
    |> UI.row("badges", children: ["badge1", "badge2"])
    |> UI.column("body", children: ["desc", "sparks", "badges"])
    |> UI.card("main", title: "Custom Components with Catalog", children: ["body"])
    |> UI.root("main")
  end

  @impl true
  def handle_action(_, state), do: {:noreply, state}
end
