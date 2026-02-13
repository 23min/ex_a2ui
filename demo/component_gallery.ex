defmodule Demo.ComponentGallery do
  @behaviour A2UI.SurfaceProvider

  alias A2UI.Builder, as: UI

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def surface(_state) do
    UI.surface("gallery")
    |> UI.theme(agent_display_name: "Component Gallery")
    # --- Display ---
    |> UI.text("txt", "Hello, A2UI!")
    |> UI.image("img", src: "https://placehold.co/120x80/1a1a2e/e94560?text=A2UI", alt: "Logo")
    |> UI.icon("ico", "star")
    |> UI.divider("div1")
    |> UI.column("display-col", children: ["txt", "img", "ico", "div1"])
    |> UI.card("display-card", title: "Display", children: ["display-col"])
    # --- Interactive ---
    |> UI.button("btn", "Click Me", action: "clicked")
    |> UI.text_field("tf", placeholder: "Type here...", bind: "/input", action: "typed")
    |> UI.checkbox("cb", label: "Accept Terms", bind: "/accepted", action: "toggled")
    |> UI.slider("sl", min: 0, max: 100, bind: "/slider_val", action: "slid")
    |> UI.date_time_input("dti", bind: "/datetime", action: "date_picked")
    |> UI.choice_picker("cp",
      options: [%{label: "Red", value: "red"}, %{label: "Blue", value: "blue"}],
      bind: "/color",
      action: "color_picked"
    )
    |> UI.column("interactive-col", children: ["btn", "tf", "cb", "sl", "dti", "cp"])
    |> UI.card("interactive-card", title: "Interactive", children: ["interactive-col"])
    # --- Media ---
    |> UI.video("vid", "https://www.w3schools.com/html/mov_bbb.mp4")
    |> UI.audio_player("aud", "https://www.w3schools.com/html/horse.mp3")
    |> UI.column("media-col", children: ["vid", "aud"])
    |> UI.card("media-card", title: "Media", children: ["media-col"])
    # --- Containers ---
    |> UI.text("r1", "Left")
    |> UI.text("r2", "Right")
    |> UI.row("demo-row", children: ["r1", "r2"])
    |> UI.text("c1", "Top")
    |> UI.text("c2", "Bottom")
    |> UI.column("demo-col", children: ["c1", "c2"])
    |> UI.text("l1", "Item 1")
    |> UI.text("l2", "Item 2")
    |> UI.text("l3", "Item 3")
    |> UI.list("demo-list", children: ["l1", "l2", "l3"])
    |> UI.text("tab1-body", "Tab 1 content")
    |> UI.text("tab2-body", "Tab 2 content")
    |> UI.tabs("demo-tabs", children: ["tab1-body", "tab2-body"])
    |> UI.text("modal-body", "Modal content goes here.")
    |> UI.modal("demo-modal", title: "Example Modal", children: ["modal-body"])
    |> UI.column("container-col",
      children: ["demo-row", "demo-col", "demo-list", "demo-tabs", "demo-modal"]
    )
    |> UI.card("container-card", title: "Containers", children: ["container-col"])
    # --- Custom ---
    |> UI.custom(:sparkline, "custom-demo", data: [1, 4, 2, 8, 5])
    |> UI.card("custom-card", title: "Custom", children: ["custom-demo"])
    # --- Root layout ---
    |> UI.column("root",
      children: [
        "display-card",
        "interactive-card",
        "media-card",
        "container-card",
        "custom-card"
      ]
    )
    |> UI.data("/input", "")
    |> UI.data("/accepted", false)
    |> UI.data("/slider_val", 50)
    |> UI.data("/color", "red")
    |> UI.root("root")
  end

  @impl true
  def handle_action(%A2UI.Action{name: "clicked"}, state) do
    {:noreply, state}
  end

  def handle_action(_, state), do: {:noreply, state}
end
