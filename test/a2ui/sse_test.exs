defmodule A2UI.SSETest do
  use ExUnit.Case, async: true

  alias A2UI.SSE

  describe "format_sse_event/1" do
    test "formats data as SSE event" do
      result = SSE.format_sse_event("{\"test\":true}")
      assert result == "event: a2ui\ndata: {\"test\":true}\n\n"
    end

    test "formats multiline data" do
      result = SSE.format_sse_event("[{\"a\":1},{\"b\":2}]")
      assert result == "event: a2ui\ndata: [{\"a\":1},{\"b\":2}]\n\n"
    end
  end

  describe "SSE event format compliance" do
    test "event type is a2ui" do
      event = SSE.format_sse_event("test")
      assert String.starts_with?(event, "event: a2ui\n")
    end

    test "ends with double newline" do
      event = SSE.format_sse_event("test")
      assert String.ends_with?(event, "\n\n")
    end

    test "data field contains the JSON payload" do
      json = Jason.encode!([%{"updateDataModel" => %{"surfaceId" => "s1", "data" => %{}}}])
      event = SSE.format_sse_event(json)
      [_event_line, data_line, _, _] = String.split(event, "\n")
      assert String.starts_with?(data_line, "data: ")
      payload = String.replace_prefix(data_line, "data: ", "")
      assert {:ok, _} = Jason.decode(payload)
    end
  end

  describe "integration with Encoder" do
    test "encodes full surface as SSE event" do
      alias A2UI.Builder, as: UI

      surface =
        UI.surface("test")
        |> UI.text("t1", "Hello")
        |> UI.root("t1")

      json = A2UI.Encoder.encode_surface(surface)
      event = SSE.format_sse_event(json)

      assert String.contains?(event, "updateComponents")
      assert String.contains?(event, "createSurface")
    end

    test "encodes data model update as SSE event" do
      json = A2UI.Encoder.update_data_model("s1", %{"/count" => 42})
      event = SSE.format_sse_event(json)
      assert String.contains?(event, "updateDataModel")
    end

    test "encodes path-level update as SSE event" do
      json = A2UI.Encoder.update_data_model_path("s1", "/count", 99)
      event = SSE.format_sse_event(json)
      assert String.contains?(event, "\"path\":\"/count\"")
    end

    test "encodes delete as SSE event" do
      json = A2UI.Encoder.delete_data_model_path("s1", "/old")
      event = SSE.format_sse_event(json)
      assert String.contains?(event, "\"path\":\"/old\"")
      refute String.contains?(event, "\"value\"")
    end
  end
end
