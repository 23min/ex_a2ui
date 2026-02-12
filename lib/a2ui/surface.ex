defmodule A2UI.Surface do
  @moduledoc """
  An A2UI surface — a canvas holding a flat list of components.

  A surface is the top-level container for A2UI components. It has a unique `id`,
  a list of components (flat adjacency list, not nested tree), an optional
  `root_component_id` that identifies the entry point for rendering, and an
  optional `data` map for initial data model values.

  ## Why flat?

  A2UI uses a flat adjacency list rather than nested component trees. This makes
  surfaces LLM-friendly (flat lists are easier to generate incrementally than
  nested trees) and enables efficient streaming updates (add, modify, or remove
  individual components without rebuilding the whole structure).

  Parent-child relationships are expressed via `children` property on container
  components (Card, Row, Column, etc.), which reference other component IDs.

  ## Examples

      %A2UI.Surface{
        id: "dashboard",
        root_component_id: "main-card",
        components: [
          %A2UI.Component{id: "title", type: :text, properties: %{...}},
          %A2UI.Component{id: "main-card", type: :card, properties: %{
            children: ["title"]
          }}
        ]
      }
  """

  @type t :: %__MODULE__{
          id: String.t(),
          catalog_id: String.t() | nil,
          components: [A2UI.Component.t()],
          root_component_id: String.t() | nil,
          data: map()
        }

  @enforce_keys [:id]
  defstruct [:id, :catalog_id, :root_component_id, components: [], data: %{}]

  @doc "Creates a new empty surface."
  @spec new(String.t()) :: t()
  def new(id) when is_binary(id), do: %__MODULE__{id: id}

  @doc "Adds a component to the surface."
  @spec add_component(t(), A2UI.Component.t()) :: t()
  def add_component(%__MODULE__{} = surface, %A2UI.Component{} = component) do
    %{surface | components: surface.components ++ [component]}
  end

  @doc "Sets the root component ID for rendering."
  @spec set_root(t(), String.t()) :: t()
  def set_root(%__MODULE__{} = surface, component_id) when is_binary(component_id) do
    %{surface | root_component_id: component_id}
  end

  @doc "Sets a value in the surface's data model."
  @spec put_data(t(), String.t(), term()) :: t()
  def put_data(%__MODULE__{} = surface, path, value) when is_binary(path) do
    %{surface | data: Map.put(surface.data, path, value)}
  end

  @doc "Finds a component by ID."
  @spec get_component(t(), String.t()) :: A2UI.Component.t() | nil
  def get_component(%__MODULE__{components: components}, id) do
    Enum.find(components, &(&1.id == id))
  end

  @doc "Returns the number of components in the surface."
  @spec component_count(t()) :: non_neg_integer()
  def component_count(%__MODULE__{components: components}), do: length(components)
end
