defmodule A2UI.Action do
  @moduledoc """
  An action triggered by user interaction with an A2UI component.

  Actions have a name and optional context bindings that resolve against
  the data model when the action fires.

  ## Examples

      # Simple action
      %A2UI.Action{name: "refresh"}

      # Action with context
      %A2UI.Action{name: "delete_item", context: %{
        "item_id" => %A2UI.BoundValue{path: "/selected/id"}
      }}
  """

  @type t :: %__MODULE__{
          name: String.t(),
          context: %{optional(String.t()) => A2UI.BoundValue.t()} | nil
        }

  @enforce_keys [:name]
  defstruct [:name, :context]

  @doc "Creates a simple action with no context."
  @spec new(String.t()) :: t()
  def new(name) when is_binary(name), do: %__MODULE__{name: name}

  @doc "Creates an action with context bindings."
  @spec new(String.t(), map()) :: t()
  def new(name, context) when is_binary(name) and is_map(context),
    do: %__MODULE__{name: name, context: context}
end
