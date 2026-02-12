defmodule A2UI.FunctionCallTest do
  use ExUnit.Case, async: true

  alias A2UI.{FunctionCall, BoundValue, Builder, Encoder}

  describe "struct" do
    test "creates with call only" do
      fc = %FunctionCall{call: "required"}
      assert fc.call == "required"
      assert fc.args == %{}
      assert fc.return_type == nil
    end

    test "creates with all fields" do
      fc = %FunctionCall{call: "formatString", args: %{"template" => "hi"}, return_type: "string"}
      assert fc.call == "formatString"
      assert fc.args == %{"template" => "hi"}
      assert fc.return_type == "string"
    end
  end

  describe "new/1,2,3" do
    test "creates with call only" do
      fc = FunctionCall.new("required")
      assert fc.call == "required"
      assert fc.args == %{}
      assert fc.return_type == nil
    end

    test "creates with call and args" do
      fc = FunctionCall.new("regex", %{"pattern" => "^\\d+$"})
      assert fc.call == "regex"
      assert fc.args == %{"pattern" => "^\\d+$"}
    end

    test "creates with call, args, and return type" do
      fc = FunctionCall.new("formatString", %{"template" => "hi"}, "string")
      assert fc.return_type == "string"
    end
  end

  describe "standard_functions/0" do
    test "returns 14 standard functions" do
      fns = FunctionCall.standard_functions()
      assert length(fns) == 14
      assert "formatString" in fns
      assert "required" in fns
      assert "openUrl" in fns
      assert "and" in fns
    end
  end

  describe "convenience constructors" do
    test "format_string/1" do
      fc = FunctionCall.format_string("Hello ${/name}")
      assert fc.call == "formatString"
      assert fc.args == %{"template" => "Hello ${/name}"}
      assert fc.return_type == "string"
    end

    test "open_url/1" do
      fc = FunctionCall.open_url("https://example.com")
      assert fc.call == "openUrl"
      assert fc.args == %{"url" => "https://example.com"}
    end

    test "required/1" do
      fc = FunctionCall.required(BoundValue.bind("/form/name"))
      assert fc.call == "required"
      assert fc.args["value"] == %BoundValue{path: "/form/name"}
      assert fc.return_type == "boolean"
    end

    test "regex/2" do
      fc = FunctionCall.regex(BoundValue.bind("/form/zip"), "^\\d{5}$")
      assert fc.call == "regex"
      assert fc.args["value"] == %BoundValue{path: "/form/zip"}
      assert fc.args["pattern"] == "^\\d{5}$"
    end

    test "length/2" do
      fc = FunctionCall.length(BoundValue.bind("/form/name"), min: 1, max: 50)
      assert fc.call == "length"
      assert fc.args["min"] == 1
      assert fc.args["max"] == 50
    end
  end

  describe "encoder integration" do
    test "encodes FunctionCall with args and return type" do
      surface =
        Builder.surface("test")
        |> Builder.text("t1", FunctionCall.format_string("Hello ${/name}"))

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert comp["text"] == %{
               "call" => "formatString",
               "args" => %{"template" => "Hello ${/name}"},
               "returnType" => "string"
             }
    end

    test "encodes FunctionCall without return type" do
      surface =
        Builder.surface("test")
        |> Builder.text("t1", FunctionCall.open_url("https://example.com"))

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      refute Map.has_key?(comp["text"], "returnType")
      assert comp["text"]["call"] == "openUrl"
    end

    test "encodes FunctionCall with no args" do
      fc = FunctionCall.new("noop")

      surface =
        Builder.surface("test")
        |> Builder.text("t1", fc)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert comp["text"] == %{"call" => "noop"}
    end

    test "encodes FunctionCall with BoundValue args (recursive)" do
      fc = FunctionCall.required(BoundValue.bind("/form/name"))

      surface =
        Builder.surface("test")
        |> Builder.text("t1", fc)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert comp["text"]["args"]["value"] == %{"path" => "/form/name"}
    end

    test "encodes nested FunctionCall in args" do
      inner = FunctionCall.format_string("${/count} items")

      outer =
        FunctionCall.new(
          "pluralize",
          %{"count" => BoundValue.bind("/count"), "singular" => inner},
          "string"
        )

      surface =
        Builder.surface("test")
        |> Builder.text("t1", outer)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert comp["text"]["call"] == "pluralize"
      assert comp["text"]["args"]["count"] == %{"path" => "/count"}
      assert comp["text"]["args"]["singular"]["call"] == "formatString"
    end
  end

  describe "builder integration" do
    test "Builder.format_string/1" do
      fc = Builder.format_string("Hello ${/name}")
      assert %FunctionCall{call: "formatString"} = fc
    end

    test "Builder.open_url/1" do
      fc = Builder.open_url("https://example.com")
      assert %FunctionCall{call: "openUrl"} = fc
    end
  end
end
