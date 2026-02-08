defmodule A2UI.ComponentTest do
  use ExUnit.Case, async: true

  alias A2UI.Component

  test "standard_types returns all standard types" do
    types = Component.standard_types()
    assert :text in types
    assert :button in types
    assert :card in types
    assert :row in types
    assert :column in types
    assert :modal in types
    assert :slider in types
    assert length(types) == 17
  end

  test "standard_type? returns true for standard types" do
    assert Component.standard_type?(:text)
    assert Component.standard_type?(:button)
    assert Component.standard_type?(:card)
  end

  test "standard_type? returns false for custom types" do
    refute Component.standard_type?(:graph)
    refute Component.standard_type?(:timeline)
  end

  test "component struct requires id and type" do
    comp = %Component{id: "test", type: :text}
    assert comp.id == "test"
    assert comp.type == :text
    assert comp.properties == %{}
  end

  test "component struct accepts properties" do
    comp = %Component{
      id: "test",
      type: :text,
      properties: %{text: A2UI.BoundValue.literal("hello")}
    }

    assert comp.properties.text.literal == "hello"
  end
end
