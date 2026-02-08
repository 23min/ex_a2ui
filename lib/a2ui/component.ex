defmodule A2UI.Component do
  @moduledoc """
  A single UI component in an A2UI surface.

  Components are the building blocks of A2UI surfaces. Each has a unique `id`,
  a `type` (from the standard catalog or custom), and type-specific `properties`.

  ## Standard component types

  Layout:
  - `:row` — horizontal layout
  - `:column` — vertical layout
  - `:list` — scrollable list with item template

  Display:
  - `:text` — text content
  - `:image` — image display
  - `:icon` — icon
  - `:video` — video player
  - `:divider` — visual separator

  Interactive:
  - `:button` — clickable button
  - `:text_field` — text input
  - `:checkbox` — boolean toggle
  - `:date_time_input` — date/time picker
  - `:slider` — range slider
  - `:multiple_choice` — selection from options

  Container:
  - `:card` — grouped content
  - `:tabs` — tabbed sections
  - `:modal` — overlay dialog

  ## Examples

      %A2UI.Component{
        id: "greeting",
        type: :text,
        properties: %{text: %A2UI.BoundValue{literal: "Hello, world!"}}
      }

      %A2UI.Component{
        id: "submit",
        type: :button,
        properties: %{
          label: %A2UI.BoundValue{literal: "Submit"},
          action: %A2UI.Action{name: "submit_form"}
        }
      }
  """

  @type component_type ::
          :row
          | :column
          | :list
          | :text
          | :image
          | :icon
          | :video
          | :divider
          | :button
          | :text_field
          | :checkbox
          | :date_time_input
          | :slider
          | :multiple_choice
          | :card
          | :tabs
          | :modal
          | {:custom, atom()}

  @type t :: %__MODULE__{
          id: String.t(),
          type: component_type(),
          properties: map()
        }

  @enforce_keys [:id, :type]
  defstruct [:id, :type, properties: %{}]

  @standard_types ~w(
    row column list
    text image icon video divider
    button text_field checkbox date_time_input slider multiple_choice
    card tabs modal
  )a

  @doc "Returns the list of standard A2UI component types."
  @spec standard_types() :: [atom()]
  def standard_types, do: @standard_types

  @doc "Returns true if the given type is a standard A2UI component type."
  @spec standard_type?(atom()) :: boolean()
  def standard_type?(type) when is_atom(type), do: type in @standard_types
end
