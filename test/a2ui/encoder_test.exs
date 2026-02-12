defmodule A2UI.EncoderTest do
  use ExUnit.Case, async: true

  alias A2UI.{Encoder, Builder}

  # Helper to decode array-wrapped messages and return the first message
  defp decode_first(json) do
    [msg | _] = Jason.decode!(json)
    msg
  end

  describe "update_components/1" do
    test "encodes a surface with text component" do
      surface =
        Builder.surface("test")
        |> Builder.text("title", "Hello")

      json = Encoder.update_components(surface)
      msg = decode_first(json)

      assert msg["version"] == "v0.9"
      assert msg["updateComponents"]["surfaceId"] == "test"
      assert length(msg["updateComponents"]["components"]) == 1

      [comp] = msg["updateComponents"]["components"]
      assert comp["id"] == "title"
      assert comp["component"] == "Text"
      assert comp["text"] == "Hello"
    end

    test "encodes a surface with bound text" do
      surface =
        Builder.surface("test")
        |> Builder.text("health", bind: "/system/health")

      json = Encoder.update_components(surface)
      msg = decode_first(json)

      [comp] = msg["updateComponents"]["components"]
      assert comp["component"] == "Text"
      assert comp["text"] == %{"path" => "/system/health"}
    end

    test "encodes a surface with button and action" do
      surface =
        Builder.surface("test")
        |> Builder.button("btn", "Click Me", action: "do_thing")

      json = Encoder.update_components(surface)
      msg = decode_first(json)

      [comp] = msg["updateComponents"]["components"]
      assert comp["component"] == "Button"
      assert comp["label"] == "Click Me"
      assert comp["action"] == %{"event" => %{"name" => "do_thing"}}
    end

    test "encodes card with children" do
      surface =
        Builder.surface("test")
        |> Builder.text("t1", "Hello")
        |> Builder.card("c1", children: ["t1"])

      json = Encoder.update_components(surface)
      msg = decode_first(json)

      components = msg["updateComponents"]["components"]
      assert length(components) == 2

      card = Enum.find(components, &(&1["id"] == "c1"))
      assert card["component"] == "Card"
      assert card["children"] == ["t1"]
    end

    test "encodes custom component type" do
      surface =
        Builder.surface("test")
        |> Builder.custom(:graph, "my-graph", nodes: "[]", edges: "[]")

      json = Encoder.update_components(surface)
      msg = decode_first(json)

      [comp] = msg["updateComponents"]["components"]
      assert comp["component"] == "graph"
    end

    test "encodes bound value with both literal and path (path wins in v0.9)" do
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

      json = Encoder.update_components(surface)
      msg = decode_first(json)

      [comp] = msg["updateComponents"]["components"]
      # v0.9: when both are set, path takes precedence
      assert comp["text"] == %{"path" => "/health"}
    end

    test "wraps output in JSON array" do
      surface = Builder.surface("test") |> Builder.text("t", "hi")
      json = Encoder.update_components(surface)
      decoded = Jason.decode!(json)
      assert is_list(decoded)
      assert length(decoded) == 1
    end
  end

  describe "update_data_model/2" do
    test "encodes data model update" do
      json = Encoder.update_data_model("test", %{"/health" => "ok", "/count" => 42})
      msg = decode_first(json)

      assert msg["version"] == "v0.9"
      assert msg["updateDataModel"]["surfaceId"] == "test"
      assert msg["updateDataModel"]["data"]["/health"] == "ok"
      assert msg["updateDataModel"]["data"]["/count"] == 42
    end
  end

  describe "create_surface/1" do
    test "encodes create surface message" do
      surface = %A2UI.Surface{id: "test", root_component_id: "root"}
      json = Encoder.create_surface(surface)
      msg = decode_first(json)

      assert msg["version"] == "v0.9"
      assert msg["createSurface"]["surfaceId"] == "test"
      assert msg["createSurface"]["rootComponentId"] == "root"
    end

    test "defaults rootComponentId to 'root' when nil" do
      surface = %A2UI.Surface{id: "test"}
      json = Encoder.create_surface(surface)
      msg = decode_first(json)

      assert msg["createSurface"]["rootComponentId"] == "root"
    end

    test "includes catalogId when provided" do
      surface = %A2UI.Surface{id: "test", catalog_id: "my-catalog", root_component_id: "root"}
      json = Encoder.create_surface(surface)
      msg = decode_first(json)

      assert msg["createSurface"]["catalogId"] == "my-catalog"
    end
  end

  describe "delete_surface/1" do
    test "encodes delete surface message" do
      json = Encoder.delete_surface("test")
      msg = decode_first(json)

      assert msg["version"] == "v0.9"
      assert msg["deleteSurface"]["surfaceId"] == "test"
    end
  end

  describe "encode_surface/1" do
    test "produces single JSON array with updateComponents only when no root or data" do
      surface = Builder.surface("test") |> Builder.text("t", "hi")
      json = Encoder.encode_surface(surface)
      messages = Jason.decode!(json)

      assert length(messages) == 1
      assert hd(messages) |> Map.has_key?("updateComponents")
      assert hd(messages)["version"] == "v0.9"
    end

    test "includes updateDataModel when data is present" do
      surface =
        Builder.surface("test")
        |> Builder.text("t", bind: "/val")
        |> Builder.data("/val", "hello")

      json = Encoder.encode_surface(surface)
      messages = Jason.decode!(json)
      assert length(messages) == 2

      types = Enum.flat_map(messages, fn m -> Map.keys(m) -- ["version"] end)
      assert "updateComponents" in types
      assert "updateDataModel" in types
    end

    test "includes createSurface when root is set" do
      surface =
        Builder.surface("test")
        |> Builder.text("t", "hi")
        |> Builder.root("t")

      json = Encoder.encode_surface(surface)
      messages = Jason.decode!(json)
      assert length(messages) == 2

      types = Enum.flat_map(messages, fn m -> Map.keys(m) -- ["version"] end)
      assert "updateComponents" in types
      assert "createSurface" in types
    end

    test "includes all three message types when surface has data and root" do
      surface =
        Builder.surface("test")
        |> Builder.text("t", bind: "/val")
        |> Builder.data("/val", "hi")
        |> Builder.root("t")

      json = Encoder.encode_surface(surface)
      messages = Jason.decode!(json)
      assert length(messages) == 3
    end

    test "returns a single JSON string (not a list)" do
      surface = Builder.surface("test") |> Builder.text("t", "hi")
      result = Encoder.encode_surface(surface)
      assert is_binary(result)
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

      json = Encoder.update_components(surface)
      msg = decode_first(json)

      [comp] = msg["updateComponents"]["components"]
      # v0.9: properties are at top level, not nested under type key
      assert comp["component"] == "TextField"
      assert comp["placeholder"] == "Type here"
      assert Map.has_key?(comp, "maxLength")
    end
  end
end
