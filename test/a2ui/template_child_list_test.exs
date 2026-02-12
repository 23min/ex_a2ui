defmodule A2UI.TemplateChildListTest do
  use ExUnit.Case, async: true

  alias A2UI.{TemplateChildList, Builder, Encoder}

  describe "struct" do
    test "creates with path and component_id" do
      tcl = %TemplateChildList{path: "/items", component_id: "item-tpl"}
      assert tcl.path == "/items"
      assert tcl.component_id == "item-tpl"
    end
  end

  describe "new/2" do
    test "creates a template child list" do
      tcl = TemplateChildList.new("/messages", "msg-tpl")
      assert tcl.path == "/messages"
      assert tcl.component_id == "msg-tpl"
    end
  end

  describe "encoder integration" do
    test "encodes TemplateChildList to wire format" do
      surface =
        Builder.surface("test")
        |> Builder.text("item-tpl", "template")
        |> Builder.column("list", children: TemplateChildList.new("/items", "item-tpl"))

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comps = msg["updateComponents"]["components"]
      col = Enum.find(comps, &(&1["id"] == "list"))

      assert col["children"] == %{
               "path" => "/items",
               "componentId" => "item-tpl"
             }
    end

    test "static children still encode as list" do
      surface =
        Builder.surface("test")
        |> Builder.text("a", "A")
        |> Builder.text("b", "B")
        |> Builder.row("r", children: ["a", "b"])

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comps = msg["updateComponents"]["components"]
      row = Enum.find(comps, &(&1["id"] == "r"))

      assert row["children"] == ["a", "b"]
    end
  end

  describe "builder integration" do
    test "Builder.template_children/2" do
      tcl = Builder.template_children("/items", "item-tpl")
      assert %TemplateChildList{path: "/items", component_id: "item-tpl"} = tcl
    end

    test "card with template children" do
      surface =
        Builder.surface("test")
        |> Builder.card("c", children: Builder.template_children("/items", "tpl"))

      comp = A2UI.Surface.get_component(surface, "c")
      assert %TemplateChildList{path: "/items"} = comp.properties.children
    end

    test "row with template children" do
      surface =
        Builder.surface("test")
        |> Builder.row("r", children: Builder.template_children("/rows", "row-tpl"))

      comp = A2UI.Surface.get_component(surface, "r")
      assert %TemplateChildList{} = comp.properties.children
    end

    test "column with template children" do
      surface =
        Builder.surface("test")
        |> Builder.column("c", children: Builder.template_children("/cols", "col-tpl"))

      comp = A2UI.Surface.get_component(surface, "c")
      assert %TemplateChildList{} = comp.properties.children
    end

    test "modal with template children" do
      surface =
        Builder.surface("test")
        |> Builder.modal("m", children: Builder.template_children("/pages", "page-tpl"))

      comp = A2UI.Surface.get_component(surface, "m")
      assert %TemplateChildList{} = comp.properties.children
    end
  end
end
