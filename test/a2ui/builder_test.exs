defmodule A2UI.BuilderTest do
  use ExUnit.Case, async: true

  alias A2UI.{Builder, Surface, BoundValue, Action}

  describe "surface construction" do
    test "creates an empty surface" do
      s = Builder.surface("test")
      assert %Surface{id: "test", components: []} = s
    end

    test "sets root component" do
      s = Builder.surface("test") |> Builder.root("main")
      assert s.root_component_id == "main"
    end

    test "sets data model values" do
      s = Builder.surface("test") |> Builder.data("/key", "value")
      assert s.data == %{"/key" => "value"}
    end

    test "sets multiple data model values" do
      s =
        Builder.surface("test")
        |> Builder.data("/a", 1)
        |> Builder.data("/b", 2)

      assert s.data == %{"/a" => 1, "/b" => 2}
    end
  end

  describe "text component" do
    test "adds text with literal value" do
      s = Builder.surface("test") |> Builder.text("t", "Hello")
      assert Surface.component_count(s) == 1

      comp = Surface.get_component(s, "t")
      assert comp.type == :text
      assert comp.properties.text == %BoundValue{literal: "Hello"}
    end

    test "adds text with binding" do
      s = Builder.surface("test") |> Builder.text("t", bind: "/name")

      comp = Surface.get_component(s, "t")
      assert comp.properties.text == %BoundValue{path: "/name"}
    end
  end

  describe "button component" do
    test "adds button with label" do
      s = Builder.surface("test") |> Builder.button("b", "Click")

      comp = Surface.get_component(s, "b")
      assert comp.type == :button
      assert comp.properties.label == %BoundValue{literal: "Click"}
      refute Map.has_key?(comp.properties, :action)
    end

    test "adds button with action string" do
      s = Builder.surface("test") |> Builder.button("b", "Go", action: "go")

      comp = Surface.get_component(s, "b")
      assert comp.properties.action == %Action{name: "go"}
    end

    test "adds button with Action struct" do
      action = Action.new("go", %{"id" => BoundValue.bind("/selected")})
      s = Builder.surface("test") |> Builder.button("b", "Go", action: action)

      comp = Surface.get_component(s, "b")
      assert comp.properties.action == action
    end
  end

  describe "text_field component" do
    test "adds text field with binding" do
      s = Builder.surface("test") |> Builder.text_field("f", bind: "/input")

      comp = Surface.get_component(s, "f")
      assert comp.type == :text_field
      assert comp.properties.value == %BoundValue{path: "/input"}
    end

    test "adds text field with placeholder" do
      s = Builder.surface("test") |> Builder.text_field("f", placeholder: "Type here")

      comp = Surface.get_component(s, "f")
      assert comp.properties.placeholder == %BoundValue{literal: "Type here"}
    end
  end

  describe "checkbox component" do
    test "adds checkbox with label and binding" do
      s =
        Builder.surface("test")
        |> Builder.checkbox("cb", label: "Accept", bind: "/accepted")

      comp = Surface.get_component(s, "cb")
      assert comp.type == :checkbox
      assert comp.properties.label == %BoundValue{literal: "Accept"}
      assert comp.properties.checked == %BoundValue{path: "/accepted"}
    end
  end

  describe "container components" do
    test "adds card with children" do
      s =
        Builder.surface("test")
        |> Builder.text("t", "Hi")
        |> Builder.card("c", children: ["t"])

      comp = Surface.get_component(s, "c")
      assert comp.type == :card
      assert comp.properties.children == ["t"]
    end

    test "adds row with children" do
      s = Builder.surface("test") |> Builder.row("r", children: ["a", "b"])

      comp = Surface.get_component(s, "r")
      assert comp.type == :row
      assert comp.properties.children == ["a", "b"]
    end

    test "adds column with children" do
      s = Builder.surface("test") |> Builder.column("col", children: ["a"])

      comp = Surface.get_component(s, "col")
      assert comp.type == :column
    end

    test "adds modal with title and children" do
      s = Builder.surface("test") |> Builder.modal("m", title: "Confirm", children: ["body"])

      comp = Surface.get_component(s, "m")
      assert comp.type == :modal
      assert comp.properties.title == %BoundValue{literal: "Confirm"}
      assert comp.properties.children == ["body"]
    end
  end

  describe "date_time_input component" do
    test "adds date_time_input with binding and action" do
      s = Builder.surface("test") |> Builder.date_time_input("dt", bind: "/date", action: "pick")

      comp = Surface.get_component(s, "dt")
      assert comp.type == :date_time_input
      assert comp.properties.value == %BoundValue{path: "/date"}
      assert comp.properties.action == %Action{name: "pick"}
    end
  end

  describe "choice_picker component" do
    test "adds choice_picker with options and binding" do
      opts = [%{label: "Red", value: "r"}, %{label: "Blue", value: "b"}]

      s =
        Builder.surface("test")
        |> Builder.choice_picker("cp", options: opts, bind: "/color", action: "select")

      comp = Surface.get_component(s, "cp")
      assert comp.type == :choice_picker
      assert comp.properties.value == %BoundValue{path: "/color"}
      assert comp.properties.options == opts
      assert comp.properties.action == %Action{name: "select"}
    end
  end

  describe "icon component" do
    test "adds icon with literal name" do
      s = Builder.surface("test") |> Builder.icon("i", "star")

      comp = Surface.get_component(s, "i")
      assert comp.type == :icon
      assert comp.properties.icon == %BoundValue{literal: "star"}
    end
  end

  describe "video component" do
    test "adds video with literal src" do
      s = Builder.surface("test") |> Builder.video("v", "https://example.com/video.mp4")

      comp = Surface.get_component(s, "v")
      assert comp.type == :video
      assert comp.properties.src == %BoundValue{literal: "https://example.com/video.mp4"}
    end
  end

  describe "audio_player component" do
    test "adds audio_player with literal src" do
      s = Builder.surface("test") |> Builder.audio_player("a", "https://example.com/audio.mp3")

      comp = Surface.get_component(s, "a")
      assert comp.type == :audio_player
      assert comp.properties.src == %BoundValue{literal: "https://example.com/audio.mp3"}
    end
  end

  describe "list component" do
    test "adds list with children" do
      s = Builder.surface("test") |> Builder.list("l", children: ["a", "b", "c"])

      comp = Surface.get_component(s, "l")
      assert comp.type == :list
      assert comp.properties.children == ["a", "b", "c"]
    end
  end

  describe "tabs component" do
    test "adds tabs with title and children" do
      s =
        Builder.surface("test")
        |> Builder.tabs("t", title: "Settings", children: ["tab1", "tab2"])

      comp = Surface.get_component(s, "t")
      assert comp.type == :tabs
      assert comp.properties.title == %BoundValue{literal: "Settings"}
      assert comp.properties.children == ["tab1", "tab2"]
    end
  end

  describe "custom component" do
    test "adds custom typed component" do
      s = Builder.surface("test") |> Builder.custom(:graph, "g", nodes: [], edges: [])

      comp = Surface.get_component(s, "g")
      assert comp.type == {:custom, :graph}
      assert comp.properties == %{nodes: [], edges: []}
    end
  end

  describe "pipeline composition" do
    test "builds a complete surface with multiple components" do
      s =
        Builder.surface("dashboard")
        |> Builder.text("title", "Dashboard")
        |> Builder.text("health", bind: "/health")
        |> Builder.button("refresh", "Refresh", action: "refresh")
        |> Builder.divider("sep")
        |> Builder.card("main", children: ["title", "health", "refresh", "sep"])
        |> Builder.data("/health", "operational")
        |> Builder.root("main")

      assert Surface.component_count(s) == 5
      assert s.root_component_id == "main"
      assert s.data == %{"/health" => "operational"}
    end
  end
end
