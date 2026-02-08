defmodule A2UI.DecoderTest do
  use ExUnit.Case, async: true

  alias A2UI.Decoder

  describe "decode/1" do
    test "decodes a simple user action" do
      json =
        Jason.encode!(%{
          "userAction" => %{
            "action" => %{"name" => "refresh"}
          }
        })

      assert {:ok, {:user_action, action}} = Decoder.decode(json)
      assert action.name == "refresh"
      assert action.context == nil
    end

    test "decodes user action with context" do
      json =
        Jason.encode!(%{
          "userAction" => %{
            "action" => %{
              "name" => "select_item",
              "context" => %{"item_id" => "42"}
            }
          }
        })

      assert {:ok, {:user_action, action}} = Decoder.decode(json)
      assert action.name == "select_item"
      assert action.context == %{"item_id" => "42"}
    end

    test "returns error for unknown message type" do
      json = Jason.encode!(%{"unknownType" => %{}})
      assert {:error, {:unknown_message, _}} = Decoder.decode(json)
    end

    test "returns error for invalid JSON" do
      assert {:error, {:json_parse_error, _}} = Decoder.decode("not json")
    end

    test "returns error for malformed user action" do
      json = Jason.encode!(%{"userAction" => %{"noAction" => true}})
      assert {:error, {:invalid_user_action, _}} = Decoder.decode(json)
    end
  end
end
