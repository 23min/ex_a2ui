defmodule A2UI.Catalog do
  @moduledoc """
  Registry for custom A2UI component types.

  A catalog defines which custom component types are available, along with
  their descriptions, properties, and required properties. This enables
  server-side validation of custom components before they are sent to clients.

  Standard component types (Text, Button, Card, etc.) are always valid and
  do not need to be registered.

  ## Example

      catalog = A2UI.Catalog.new("my-app-v1")
      |> A2UI.Catalog.register("Graph", description: "Network graph", properties: [:nodes, :edges], required: [:nodes])
      |> A2UI.Catalog.register("Sparkline", description: "Inline chart", properties: [:data, :color])

      A2UI.Catalog.types(catalog)
      # => ["Graph", "Sparkline"]

      A2UI.Catalog.validate_component(catalog, component)
      # => :ok | {:error, reason}
  """

  @type type_spec :: %{
          description: String.t() | nil,
          properties: [atom()] | :any,
          required: [atom()]
        }

  @type t :: %__MODULE__{
          id: String.t(),
          types: %{String.t() => type_spec()}
        }

  @enforce_keys [:id]
  defstruct [:id, types: %{}]

  @standard_types ~w(Text Button TextField CheckBox DateTimeInput Slider ChoicePicker
    Image Icon Video AudioPlayer Divider Row Column List Card Tabs Modal)

  @doc "Creates a new empty catalog with the given ID."
  @spec new(String.t()) :: t()
  def new(id) when is_binary(id), do: %__MODULE__{id: id}

  @doc """
  Registers a custom component type in the catalog.

  ## Options

  - `:description` — human-readable description
  - `:properties` — list of allowed property atoms, or `:any` (default: `:any`)
  - `:required` — list of required property atoms (default: `[]`)
  """
  @spec register(t(), String.t(), keyword()) :: t()
  def register(%__MODULE__{} = catalog, type_name, opts \\ []) when is_binary(type_name) do
    spec = %{
      description: Keyword.get(opts, :description),
      properties: Keyword.get(opts, :properties, :any),
      required: Keyword.get(opts, :required, [])
    }

    %{catalog | types: Map.put(catalog.types, type_name, spec)}
  end

  @doc "Returns the list of registered custom type names."
  @spec types(t()) :: [String.t()]
  def types(%__MODULE__{types: types}), do: Map.keys(types)

  @doc "Returns true if the type is registered in the catalog."
  @spec has_type?(t(), String.t()) :: boolean()
  def has_type?(%__MODULE__{types: types}, type_name), do: Map.has_key?(types, type_name)

  @doc "Returns the spec for a registered type, or nil."
  @spec get_spec(t(), String.t()) :: type_spec() | nil
  def get_spec(%__MODULE__{types: types}, type_name), do: Map.get(types, type_name)

  @doc """
  Validates a component against the catalog.

  Standard component types always pass. Custom components must be registered
  in the catalog and satisfy property requirements.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec validate_component(t(), A2UI.Component.t()) :: :ok | {:error, term()}
  def validate_component(%__MODULE__{} = catalog, %A2UI.Component{} = component) do
    type_name = resolve_type_name(component.type)

    cond do
      type_name in @standard_types ->
        :ok

      not has_type?(catalog, type_name) ->
        {:error, {:unknown_type, type_name}}

      true ->
        validate_properties(catalog, type_name, component.properties)
    end
  end

  defp resolve_type_name({:custom, name}), do: Atom.to_string(name)
  defp resolve_type_name(atom) when is_atom(atom), do: encode_type_key(atom)

  defp validate_properties(%__MODULE__{} = catalog, type_name, properties) do
    spec = get_spec(catalog, type_name)
    prop_keys = Map.keys(properties)

    # Check required properties
    missing = Enum.filter(spec.required, fn req -> req not in prop_keys end)

    if missing != [] do
      {:error, {:missing_required, missing}}
    else
      validate_allowed_properties(spec.properties, prop_keys)
    end
  end

  defp validate_allowed_properties(:any, _prop_keys), do: :ok

  defp validate_allowed_properties(allowed, prop_keys) when is_list(allowed) do
    disallowed = Enum.filter(prop_keys, fn k -> k not in allowed end)

    if disallowed != [] do
      {:error, {:disallowed_properties, disallowed}}
    else
      :ok
    end
  end

  # Mirror of Encoder type key mapping for standard type lookup
  defp encode_type_key(:text), do: "Text"
  defp encode_type_key(:button), do: "Button"
  defp encode_type_key(:text_field), do: "TextField"
  defp encode_type_key(:checkbox), do: "CheckBox"
  defp encode_type_key(:date_time_input), do: "DateTimeInput"
  defp encode_type_key(:slider), do: "Slider"
  defp encode_type_key(:choice_picker), do: "ChoicePicker"
  defp encode_type_key(:image), do: "Image"
  defp encode_type_key(:icon), do: "Icon"
  defp encode_type_key(:video), do: "Video"
  defp encode_type_key(:audio_player), do: "AudioPlayer"
  defp encode_type_key(:divider), do: "Divider"
  defp encode_type_key(:row), do: "Row"
  defp encode_type_key(:column), do: "Column"
  defp encode_type_key(:list), do: "List"
  defp encode_type_key(:card), do: "Card"
  defp encode_type_key(:tabs), do: "Tabs"
  defp encode_type_key(:modal), do: "Modal"
  defp encode_type_key(other), do: Atom.to_string(other)
end
