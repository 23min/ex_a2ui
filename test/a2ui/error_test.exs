defmodule A2UI.ErrorTest do
  use ExUnit.Case, async: true

  alias A2UI.Error

  describe "struct" do
    test "creates with type only" do
      error = %Error{type: "GENERIC"}
      assert error.type == "GENERIC"
      assert error.path == nil
      assert error.message == nil
    end

    test "creates with all fields" do
      error = %Error{type: "VALIDATION_FAILED", path: "/form/email", message: "Invalid"}
      assert error.type == "VALIDATION_FAILED"
      assert error.path == "/form/email"
      assert error.message == "Invalid"
    end
  end

  describe "new/1" do
    test "creates from map" do
      error = Error.new(%{type: "GENERIC", message: "Something went wrong"})
      assert error.type == "GENERIC"
      assert error.message == "Something went wrong"
    end
  end

  describe "validation_failed/2" do
    test "creates VALIDATION_FAILED error" do
      error = Error.validation_failed("/form/name", "Required")
      assert error.type == "VALIDATION_FAILED"
      assert error.path == "/form/name"
      assert error.message == "Required"
    end

    test "creates VALIDATION_FAILED without message" do
      error = Error.validation_failed("/form/name")
      assert error.type == "VALIDATION_FAILED"
      assert error.path == "/form/name"
      assert error.message == nil
    end
  end
end
