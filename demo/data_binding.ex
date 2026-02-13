defmodule Demo.DataBinding do
  @behaviour A2UI.SurfaceProvider

  alias A2UI.Builder, as: UI

  @impl true
  def init(_opts), do: {:ok, %{name: "World", slider: 50}}

  @impl true
  def surface(state) do
    UI.surface("data-binding")
    |> UI.theme(agent_display_name: "Data Binding Demo")
    # Input section
    |> UI.text("name-label", "Your name:")
    |> UI.text_field("name-input", bind: "/name", placeholder: "Enter your name", action: "name_changed")
    |> UI.row("name-row", children: ["name-label", "name-input"])
    # Reactive output
    |> UI.text("greeting", UI.format_string("Hello, {/name}!"))
    # Slider with live value
    |> UI.text("slider-label", "Slider value:")
    |> UI.slider("slider", min: 0, max: 100, bind: "/slider", action: "slider_changed")
    |> UI.text("slider-val", bind: "/slider")
    |> UI.row("slider-row", children: ["slider-label", "slider", "slider-val"])
    # Color binding
    |> UI.text("color-label", "Favorite color:")
    |> UI.choice_picker("color-picker",
      options: [
        %{label: "Red", value: "red"},
        %{label: "Green", value: "green"},
        %{label: "Blue", value: "blue"}
      ],
      bind: "/color",
      action: "color_changed"
    )
    |> UI.text("color-display", bind: "/color")
    |> UI.row("color-row", children: ["color-label", "color-picker", "color-display"])
    # Layout
    |> UI.column("body", children: ["name-row", "greeting", "slider-row", "color-row"])
    |> UI.card("main", title: "Reactive Data Binding", children: ["body"])
    |> UI.root("main")
    |> UI.data("/name", state.name)
    |> UI.data("/slider", state.slider)
    |> UI.data("/color", "red")
  end

  @impl true
  def handle_action(%A2UI.Action{name: "name_changed"}, state) do
    # In a real app, the new value comes from the data model sent by the client.
    # For the demo, we just acknowledge.
    {:noreply, state}
  end

  def handle_action(%A2UI.Action{name: "slider_changed"}, state) do
    {:noreply, state}
  end

  def handle_action(_, state), do: {:noreply, state}
end
