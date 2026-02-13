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

  describe "decode/1 with error messages" do
    test "decodes a client error message" do
      json =
        Jason.encode!([
          %{
            "error" => %{
              "type" => "VALIDATION_FAILED",
              "path" => "/form/email",
              "message" => "Invalid email",
              "surfaceId" => "s1"
            }
          }
        ])

      assert {:ok, [{:error, error, metadata}]} = Decoder.decode(json)
      assert %A2UI.Error{} = error
      assert error.type == "VALIDATION_FAILED"
      assert error.path == "/form/email"
      assert error.message == "Invalid email"
      assert metadata.surface_id == "s1"
    end

    test "decodes error without optional fields" do
      json =
        Jason.encode!([
          %{
            "error" => %{"type" => "GENERIC"}
          }
        ])

      assert {:ok, [{:error, error, metadata}]} = Decoder.decode(json)
      assert error.type == "GENERIC"
      assert error.path == nil
      assert error.message == nil
      assert metadata.surface_id == nil
    end

    test "returns error for malformed error message" do
      json = Jason.encode!([%{"error" => %{"noType" => true}}])
      assert {:error, {:invalid_error, _}} = Decoder.decode(json)
    end

    test "decodes mixed action and error messages" do
      json =
        Jason.encode!([
          %{"action" => %{"event" => %{"name" => "submit"}, "surfaceId" => "s1"}},
          %{"error" => %{"type" => "VALIDATION_FAILED", "path" => "/email"}}
        ])

      assert {:ok, [action_msg, error_msg]} = Decoder.decode(json)
      assert {:action, _, _} = action_msg
      assert {:error, %A2UI.Error{type: "VALIDATION_FAILED"}, _} = error_msg
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
