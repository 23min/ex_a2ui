defmodule A2UI.EncoderTest do
  use ExUnit.Case, async: true

  alias A2UI.{Encoder, Builder}

  describe "surface_update/1" do
    test "encodes a surface with text component" do
      surface =
        Builder.surface("test")
        |> Builder.text("title", "Hello")

      json = Encoder.surface_update(surface)
      decoded = Jason.decode!(json)

      assert decoded["surfaceUpdate"]["surfaceId"] == "test"
      assert length(decoded["surfaceUpdate"]["components"]) == 1

      [comp] = decoded["surfaceUpdate"]["components"]
      assert comp["id"] == "title"
      assert comp["component"]["Text"]["text"]["literalString"] == "Hello"
    end

    test "encodes a surface with bound text" do
      surface =
        Builder.surface("test")
        |> Builder.text("health", bind: "/system/health")

      json = Encoder.surface_update(surface)
      decoded = Jason.decode!(json)

      [comp] = decoded["surfaceUpdate"]["components"]
      assert comp["component"]["Text"]["text"]["path"] == "/system/health"
      refute Map.has_key?(comp["component"]["Text"]["text"], "literalString")
    end

    test "encodes a surface with button and action" do
      surface =
        Builder.surface("test")
        |> Builder.button("btn", "Click Me", action: "do_thing")

      json = Encoder.surface_update(surface)
      decoded = Jason.decode!(json)

      [comp] = decoded["surfaceUpdate"]["components"]
      assert comp["component"]["Button"]["label"]["literalString"] == "Click Me"
      assert comp["component"]["Button"]["action"]["name"] == "do_thing"
    end

    test "encodes card with children" do
      surface =
        Builder.surface("test")
        |> Builder.text("t1", "Hello")
        |> Builder.card("c1", children: ["t1"])

      json = Encoder.surface_update(surface)
      decoded = Jason.decode!(json)

      components = decoded["surfaceUpdate"]["components"]
      assert length(components) == 2

      card = Enum.find(components, &(&1["id"] == "c1"))
      assert card["component"]["Card"]["children"] == ["t1"]
    end

    test "encodes custom component type" do
      surface =
        Builder.surface("test")
        |> Builder.custom(:graph, "my-graph", nodes: "[]", edges: "[]")

      json = Encoder.surface_update(surface)
      decoded = Jason.decode!(json)

      [comp] = decoded["surfaceUpdate"]["components"]
      assert Map.has_key?(comp["component"], "graph")
    end

    test "encodes bound value with both literal and path" do
      bv = A2UI.BoundValue.bind("/health", "loading...")

      surface = %A2UI.Surface{
        id: "test",
        components: [
          %A2UI.Component{
            id: "status",
            type: :text,
            properties: %{text: bv}
          }
        ]
      }

      json = Encoder.surface_update(surface)
      decoded = Jason.decode!(json)

      [comp] = decoded["surfaceUpdate"]["components"]
      text_val = comp["component"]["Text"]["text"]
      assert text_val["literalString"] == "loading..."
      assert text_val["path"] == "/health"
    end
  end

  describe "data_model_update/2" do
    test "encodes data model update" do
      json = Encoder.data_model_update("test", %{"/health" => "ok", "/count" => 42})
      decoded = Jason.decode!(json)

      assert decoded["dataModelUpdate"]["surfaceId"] == "test"
      assert decoded["dataModelUpdate"]["data"]["/health"] == "ok"
      assert decoded["dataModelUpdate"]["data"]["/count"] == 42
    end
  end

  describe "begin_rendering/2" do
    test "encodes begin rendering message" do
      json = Encoder.begin_rendering("test", "root")
      decoded = Jason.decode!(json)

      assert decoded["beginRendering"]["surfaceId"] == "test"
      assert decoded["beginRendering"]["rootComponentId"] == "root"
    end

    test "includes catalog_id when provided" do
      json = Encoder.begin_rendering("test", "root", catalog_id: "my-catalog")
      decoded = Jason.decode!(json)

      assert decoded["beginRendering"]["catalogId"] == "my-catalog"
    end
  end

  describe "delete_surface/1" do
    test "encodes delete surface message" do
      json = Encoder.delete_surface("test")
      decoded = Jason.decode!(json)

      assert decoded["deleteSurface"]["surfaceId"] == "test"
    end
  end

  describe "encode_surface/1" do
    test "produces surface_update only when no root or data" do
      surface = Builder.surface("test") |> Builder.text("t", "hi")
      messages = Encoder.encode_surface(surface)

      assert length(messages) == 1
      assert Jason.decode!(hd(messages)) |> Map.has_key?("surfaceUpdate")
    end

    test "includes data_model_update when data is present" do
      surface =
        Builder.surface("test")
        |> Builder.text("t", bind: "/val")
        |> Builder.data("/val", "hello")

      messages = Encoder.encode_surface(surface)
      assert length(messages) == 2

      types = Enum.map(messages, fn m -> m |> Jason.decode!() |> Map.keys() |> hd() end)
      assert "surfaceUpdate" in types
      assert "dataModelUpdate" in types
    end

    test "includes begin_rendering when root is set" do
      surface =
        Builder.surface("test")
        |> Builder.text("t", "hi")
        |> Builder.root("t")

      messages = Encoder.encode_surface(surface)
      assert length(messages) == 2

      types = Enum.map(messages, fn m -> m |> Jason.decode!() |> Map.keys() |> hd() end)
      assert "surfaceUpdate" in types
      assert "beginRendering" in types
    end

    test "includes all three message types when surface has data and root" do
      surface =
        Builder.surface("test")
        |> Builder.text("t", bind: "/val")
        |> Builder.data("/val", "hi")
        |> Builder.root("t")

      messages = Encoder.encode_surface(surface)
      assert length(messages) == 3
    end
  end

  describe "property key encoding" do
    test "converts snake_case atom keys to camelCase" do
      surface = %A2UI.Surface{
        id: "test",
        components: [
          %A2UI.Component{
            id: "field",
            type: :text_field,
            properties: %{
              placeholder: A2UI.BoundValue.literal("Type here"),
              max_length: 100
            }
          }
        ]
      }

      json = Encoder.surface_update(surface)
      decoded = Jason.decode!(json)

      [comp] = decoded["surfaceUpdate"]["components"]
      tf = comp["component"]["TextField"]
      assert Map.has_key?(tf, "placeholder")
      assert Map.has_key?(tf, "maxLength")
    end
  end
end
