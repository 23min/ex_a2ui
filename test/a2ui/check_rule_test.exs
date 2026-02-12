defmodule A2UI.CheckRuleTest do
  use ExUnit.Case, async: true

  alias A2UI.{CheckRule, FunctionCall, BoundValue, Builder, Encoder, Surface}

  describe "struct" do
    test "creates with condition and message" do
      cr = %CheckRule{condition: true, message: "Must be true"}
      assert cr.condition == true
      assert cr.message == "Must be true"
    end
  end

  describe "new/2" do
    test "creates with FunctionCall condition" do
      fc = FunctionCall.required(BoundValue.bind("/form/name"))
      cr = CheckRule.new(fc, "Required")
      assert cr.condition == fc
      assert cr.message == "Required"
    end

    test "creates with boolean literal condition" do
      cr = CheckRule.new(false, "Always fails")
      assert cr.condition == false
    end
  end

  describe "convenience constructors" do
    test "required/1 with default message" do
      cr = CheckRule.required(BoundValue.bind("/form/name"))
      assert cr.message == "This field is required"
      assert cr.condition.call == "required"
      assert cr.condition.args["value"] == BoundValue.bind("/form/name")
    end

    test "required/2 with custom message" do
      cr = CheckRule.required(BoundValue.bind("/form/email"), "Email is required")
      assert cr.message == "Email is required"
    end

    test "regex/3" do
      cr = CheckRule.regex(BoundValue.bind("/form/zip"), "^\\d{5}$", "Must be 5 digits")
      assert cr.message == "Must be 5 digits"
      assert cr.condition.call == "regex"
      assert cr.condition.args["pattern"] == "^\\d{5}$"
    end

    test "max_length/2 with default message" do
      cr = CheckRule.max_length(BoundValue.bind("/form/name"), 50)
      assert cr.message == "Too long"
      assert cr.condition.call == "length"
      assert cr.condition.args["max"] == 50
    end

    test "max_length/3 with custom message" do
      cr = CheckRule.max_length(BoundValue.bind("/form/bio"), 200, "Bio too long")
      assert cr.message == "Bio too long"
    end
  end

  describe "encoder integration" do
    test "encodes CheckRule with FunctionCall condition" do
      checks = [CheckRule.required(BoundValue.bind("/form/name"))]

      surface =
        Builder.surface("test")
        |> Builder.text_field("name", bind: "/form/name", checks: checks)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert [check] = comp["checks"]
      assert check["message"] == "This field is required"
      assert check["condition"]["call"] == "required"
      assert check["condition"]["args"]["value"] == %{"path" => "/form/name"}
      assert check["condition"]["returnType"] == "boolean"
    end

    test "encodes CheckRule with boolean literal condition" do
      checks = [CheckRule.new(true, "Always passes")]

      surface =
        Builder.surface("test")
        |> Builder.text_field("f", bind: "/form/f", checks: checks)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert [check] = comp["checks"]
      assert check["condition"] == true
      assert check["message"] == "Always passes"
    end

    test "encodes multiple checks" do
      checks = [
        CheckRule.required(BoundValue.bind("/form/zip")),
        CheckRule.regex(BoundValue.bind("/form/zip"), "^\\d{5}$", "Must be 5 digits")
      ]

      surface =
        Builder.surface("test")
        |> Builder.text_field("zip", bind: "/form/zip", checks: checks)

      json = Encoder.update_components(surface)
      [msg] = Jason.decode!(json)
      comp = hd(msg["updateComponents"]["components"])

      assert length(comp["checks"]) == 2
      assert Enum.at(comp["checks"], 0)["condition"]["call"] == "required"
      assert Enum.at(comp["checks"], 1)["condition"]["call"] == "regex"
    end
  end

  describe "builder integration" do
    test "Builder.required_check/1" do
      cr = Builder.required_check("/form/name")
      assert %CheckRule{} = cr
      assert cr.condition.call == "required"
    end

    test "Builder.required_check/2 with custom message" do
      cr = Builder.required_check("/form/name", "Name is required")
      assert cr.message == "Name is required"
    end

    test "Builder.max_length_check/2" do
      cr = Builder.max_length_check("/form/name", 50)
      assert %CheckRule{} = cr
      assert cr.condition.call == "length"
    end

    test "Builder.regex_check/3" do
      cr = Builder.regex_check("/form/zip", "^\\d{5}$", "Invalid zip")
      assert %CheckRule{} = cr
      assert cr.condition.call == "regex"
    end

    test "text_field with checks option" do
      checks = [Builder.required_check("/form/name")]

      surface =
        Builder.surface("test")
        |> Builder.text_field("name", bind: "/form/name", checks: checks)

      comp = Surface.get_component(surface, "name")
      assert [%CheckRule{}] = comp.properties.checks
    end

    test "checkbox with checks option" do
      checks = [CheckRule.new(true, "test")]

      surface =
        Builder.surface("test")
        |> Builder.checkbox("cb", bind: "/form/agree", checks: checks)

      comp = Surface.get_component(surface, "cb")
      assert [%CheckRule{}] = comp.properties.checks
    end

    test "slider with checks option" do
      checks = [CheckRule.new(true, "test")]

      surface =
        Builder.surface("test")
        |> Builder.slider("s", bind: "/form/val", checks: checks)

      comp = Surface.get_component(surface, "s")
      assert [%CheckRule{}] = comp.properties.checks
    end
  end
end
