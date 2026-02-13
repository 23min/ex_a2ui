defmodule A2UI.CatalogTest do
  use ExUnit.Case, async: true

  alias A2UI.{Catalog, Component, BoundValue, Builder}

  describe "new/1" do
    test "creates empty catalog" do
      catalog = Catalog.new("my-app-v1")
      assert catalog.id == "my-app-v1"
      assert catalog.types == %{}
    end
  end

  describe "register/3" do
    test "registers a type with defaults" do
      catalog = Catalog.new("test") |> Catalog.register("Graph")
      assert Catalog.has_type?(catalog, "Graph")
      spec = Catalog.get_spec(catalog, "Graph")
      assert spec.description == nil
      assert spec.properties == :any
      assert spec.required == []
    end

    test "registers a type with all options" do
      catalog =
        Catalog.new("test")
        |> Catalog.register("Graph",
          description: "Network graph",
          properties: [:nodes, :edges, :layout],
          required: [:nodes]
        )

      spec = Catalog.get_spec(catalog, "Graph")
      assert spec.description == "Network graph"
      assert spec.properties == [:nodes, :edges, :layout]
      assert spec.required == [:nodes]
    end
  end

  describe "types/1" do
    test "returns registered type names" do
      catalog =
        Catalog.new("test")
        |> Catalog.register("Graph")
        |> Catalog.register("Sparkline")

      types = Catalog.types(catalog)
      assert "Graph" in types
      assert "Sparkline" in types
      assert length(types) == 2
    end
  end

  describe "has_type?/2" do
    test "returns true for registered types" do
      catalog = Catalog.new("test") |> Catalog.register("Graph")
      assert Catalog.has_type?(catalog, "Graph")
    end

    test "returns false for unregistered types" do
      catalog = Catalog.new("test")
      refute Catalog.has_type?(catalog, "Unknown")
    end
  end

  describe "get_spec/2" do
    test "returns nil for unregistered types" do
      catalog = Catalog.new("test")
      assert Catalog.get_spec(catalog, "Unknown") == nil
    end
  end

  describe "validate_component/2" do
    test "standard types always pass" do
      catalog = Catalog.new("test")
      comp = %Component{id: "t1", type: :text, properties: %{text: BoundValue.literal("hi")}}
      assert :ok = Catalog.validate_component(catalog, comp)
    end

    test "returns error for unknown custom type" do
      catalog = Catalog.new("test")
      comp = %Component{id: "g1", type: {:custom, :graph}, properties: %{nodes: []}}
      assert {:error, {:unknown_type, "graph"}} = Catalog.validate_component(catalog, comp)
    end

    test "valid custom component passes" do
      catalog =
        Catalog.new("test")
        |> Catalog.register("graph", properties: [:nodes, :edges], required: [:nodes])

      comp = %Component{id: "g1", type: {:custom, :graph}, properties: %{nodes: [], edges: []}}
      assert :ok = Catalog.validate_component(catalog, comp)
    end

    test "returns error for missing required properties" do
      catalog =
        Catalog.new("test")
        |> Catalog.register("graph", properties: [:nodes, :edges], required: [:nodes])

      comp = %Component{id: "g1", type: {:custom, :graph}, properties: %{edges: []}}
      assert {:error, {:missing_required, [:nodes]}} = Catalog.validate_component(catalog, comp)
    end

    test "returns error for disallowed properties" do
      catalog =
        Catalog.new("test")
        |> Catalog.register("graph", properties: [:nodes, :edges])

      comp = %Component{id: "g1", type: {:custom, :graph}, properties: %{nodes: [], bad: true}}

      assert {:error, {:disallowed_properties, [:bad]}} =
               Catalog.validate_component(catalog, comp)
    end

    test "allows any properties when properties is :any" do
      catalog = Catalog.new("test") |> Catalog.register("graph")

      comp = %Component{
        id: "g1",
        type: {:custom, :graph},
        properties: %{anything: true, else: 42}
      }

      assert :ok = Catalog.validate_component(catalog, comp)
    end
  end

  describe "builder integration" do
    test "Builder.catalog_id/2 with string" do
      s = Builder.surface("test") |> Builder.catalog_id("my-app-v1")
      assert s.catalog_id == "my-app-v1"
    end

    test "Builder.catalog_id/2 with Catalog struct" do
      catalog = Catalog.new("my-app-v1")
      s = Builder.surface("test") |> Builder.catalog_id(catalog)
      assert s.catalog_id == "my-app-v1"
    end
  end
end
