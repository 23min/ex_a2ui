defmodule A2UI.TemplateChildList do
  @moduledoc """
  A dynamic child list that generates children from a data model array.

  Instead of static `["id1", "id2"]` child lists, a TemplateChildList
  tells the client to iterate over a data array and instantiate a
  template component for each item.

  ## Wire format

      {"path": "/items", "componentId": "item-template"}

  ## Examples

      # Each item in /messages gets rendered using the "msg-tpl" component
      %A2UI.TemplateChildList{path: "/messages", component_id: "msg-tpl"}
  """

  @type t :: %__MODULE__{
          path: String.t(),
          component_id: String.t()
        }

  @enforce_keys [:path, :component_id]
  defstruct [:path, :component_id]

  @doc "Creates a template child list."
  @spec new(String.t(), String.t()) :: t()
  def new(path, component_id) when is_binary(path) and is_binary(component_id) do
    %__MODULE__{path: path, component_id: component_id}
  end
end
