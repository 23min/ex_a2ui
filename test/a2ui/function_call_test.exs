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

    test "numeric/1" do
      fc = FunctionCall.numeric(BoundValue.bind("/form/age"))
      assert fc.call == "numeric"
      assert fc.args["value"] == %BoundValue{path: "/form/age"}
      assert fc.return_type == "boolean"
    end

    test "email/1" do
      fc = FunctionCall.email(BoundValue.bind("/form/email"))
      assert fc.call == "email"
      assert fc.args["value"] == %BoundValue{path: "/form/email"}
      assert fc.return_type == "boolean"
    end

    test "format_number/1" do
      fc = FunctionCall.format_number(BoundValue.bind("/stats/count"))
      assert fc.call == "formatNumber"
      assert fc.args["value"] == %BoundValue{path: "/stats/count"}
      assert fc.return_type == "string"
    end

    test "format_currency/2" do
      fc = FunctionCall.format_currency(BoundValue.bind("/price"), "USD")
      assert fc.call == "formatCurrency"
      assert fc.args["value"] == %BoundValue{path: "/price"}
      assert fc.args["currencyCode"] == "USD"
      assert fc.return_type == "string"
    end

    test "format_date/2" do
      fc = FunctionCall.format_date(BoundValue.bind("/created_at"), "yyyy-MM-dd")
      assert fc.call == "formatDate"
      assert fc.args["value"] == %BoundValue{path: "/created_at"}
      assert fc.args["format"] == "yyyy-MM-dd"
      assert fc.return_type == "string"
    end

    test "pluralize/3" do
      fc = FunctionCall.pluralize(BoundValue.bind("/count"), "item", "items")
      assert fc.call == "pluralize"
      assert fc.args["count"] == %BoundValue{path: "/count"}
      assert fc.args["singular"] == "item"
      assert fc.args["plural"] == "items"
      assert fc.return_type == "string"
    end

    test "fn_and/1" do
      c1 = FunctionCall.required(BoundValue.bind("/a"))
      c2 = FunctionCall.required(BoundValue.bind("/b"))
      fc = FunctionCall.fn_and([c1, c2])
      assert fc.call == "and"
      assert fc.args["conditions"] == [c1, c2]
      assert fc.return_type == "boolean"
    end

    test "fn_or/1" do
      c1 = FunctionCall.numeric(BoundValue.bind("/a"))
      c2 = FunctionCall.email(BoundValue.bind("/a"))
      fc = FunctionCall.fn_or([c1, c2])
      assert fc.call == "or"
      assert fc.args["conditions"] == [c1, c2]
      assert fc.return_type == "boolean"
    end

    test "fn_not/1" do
      inner = FunctionCall.required(BoundValue.bind("/a"))
      fc = FunctionCall.fn_not(inner)
      assert fc.call == "not"
      assert fc.args["condition"] == inner
      assert fc.return_type == "boolean"
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

  describe "encoder integration — new helpers" do
    test "encodes format_currency with args" do
      fc = FunctionCall.format_currency(BoundValue.bind("/price"), "EUR")

      surface =
        Builder.surface("test")
        |> Builder.text("t1", fc)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert comp["text"]["call"] == "formatCurrency"
      assert comp["text"]["args"]["value"] == %{"path" => "/price"}
      assert comp["text"]["args"]["currencyCode"] == "EUR"
      assert comp["text"]["returnType"] == "string"
    end

    test "encodes fn_and with nested conditions" do
      c1 = FunctionCall.required(BoundValue.bind("/a"))
      c2 = FunctionCall.numeric(BoundValue.bind("/b"))
      fc = FunctionCall.fn_and([c1, c2])

      surface =
        Builder.surface("test")
        |> Builder.text("t1", fc)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert comp["text"]["call"] == "and"
      conditions = comp["text"]["args"]["conditions"]
      assert length(conditions) == 2
      assert hd(conditions)["call"] == "required"
    end

    test "encodes fn_not wrapping another function" do
      inner = FunctionCall.email(BoundValue.bind("/val"))
      fc = FunctionCall.fn_not(inner)

      surface =
        Builder.surface("test")
        |> Builder.text("t1", fc)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert comp["text"]["call"] == "not"
      assert comp["text"]["args"]["condition"]["call"] == "email"
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

    test "Builder.numeric/1" do
      fc = Builder.numeric(BoundValue.bind("/val"))
      assert %FunctionCall{call: "numeric"} = fc
    end

    test "Builder.email/1" do
      fc = Builder.email(BoundValue.bind("/val"))
      assert %FunctionCall{call: "email"} = fc
    end

    test "Builder.format_number/1" do
      fc = Builder.format_number(BoundValue.bind("/val"))
      assert %FunctionCall{call: "formatNumber"} = fc
    end

    test "Builder.format_currency/2" do
      fc = Builder.format_currency(BoundValue.bind("/val"), "GBP")
      assert %FunctionCall{call: "formatCurrency"} = fc
    end

    test "Builder.format_date/2" do
      fc = Builder.format_date(BoundValue.bind("/val"), "MM/dd/yyyy")
      assert %FunctionCall{call: "formatDate"} = fc
    end

    test "Builder.pluralize/3" do
      fc = Builder.pluralize(BoundValue.bind("/n"), "item", "items")
      assert %FunctionCall{call: "pluralize"} = fc
    end

    test "Builder.fn_and/1" do
      fc = Builder.fn_and([FunctionCall.required(BoundValue.bind("/a"))])
      assert %FunctionCall{call: "and"} = fc
    end

    test "Builder.fn_or/1" do
      fc = Builder.fn_or([FunctionCall.required(BoundValue.bind("/a"))])
      assert %FunctionCall{call: "or"} = fc
    end

    test "Builder.fn_not/1" do
      fc = Builder.fn_not(FunctionCall.required(BoundValue.bind("/a")))
      assert %FunctionCall{call: "not"} = fc
    end
  end
end
