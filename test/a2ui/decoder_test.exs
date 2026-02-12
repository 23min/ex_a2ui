defmodule A2UI.DecoderTest do
  use ExUnit.Case, async: true

  alias A2UI.Decoder

  describe "decode/1 with v0.9 array format" do
    test "decodes a v0.9 action with event" do
      json =
        Jason.encode!([
          %{
            "action" => %{
              "event" => %{"name" => "refresh"},
              "surfaceId" => "s1",
              "sourceComponentId" => "btn1"
            }
          }
        ])

      assert {:ok, [{:action, action, metadata}]} = Decoder.decode(json)
      assert action.name == "refresh"
      assert action.context == nil
      assert metadata.surface_id == "s1"
      assert metadata.source_component_id == "btn1"
    end

    test "decodes action event with context" do
      json =
        Jason.encode!([
          %{
            "action" => %{
              "event" => %{
                "name" => "select_item",
                "context" => %{"item_id" => "42"}
              },
              "surfaceId" => "s1"
            }
          }
        ])

      assert {:ok, [{:action, action, metadata}]} = Decoder.decode(json)
      assert action.name == "select_item"
      assert action.context == %{"item_id" => "42"}
      assert metadata.surface_id == "s1"
    end

    test "decodes action with bare name (simple client fallback)" do
      json =
        Jason.encode!([
          %{
            "action" => %{"name" => "refresh"}
          }
        ])

      assert {:ok, [{:action, action, metadata}]} = Decoder.decode(json)
      assert action.name == "refresh"
      assert metadata == %{}
    end
  end

  describe "decode/1 with single object format" do
    test "accepts unwrapped single object" do
      json =
        Jason.encode!(%{
          "action" => %{
            "event" => %{"name" => "refresh"}
          }
        })

      assert {:ok, [{:action, action, _metadata}]} = Decoder.decode(json)
      assert action.name == "refresh"
    end
  end

  describe "decode/1 error cases" do
    test "returns error for unknown message type" do
      json = Jason.encode!(%{"unknownType" => %{}})
      assert {:error, {:unknown_message, _}} = Decoder.decode(json)
    end

    test "returns error for invalid JSON" do
      assert {:error, {:json_parse_error, _}} = Decoder.decode("not json")
    end

    test "returns error for malformed action" do
      json = Jason.encode!(%{"action" => %{"noEvent" => true}})
      assert {:error, {:invalid_action, _}} = Decoder.decode(json)
    end
  end
end
