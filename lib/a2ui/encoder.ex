defmodule A2UI.Encoder do
  @moduledoc """
  Encodes A2UI Elixir structs into v0.9 JSON wire format.

  Produces the JSON messages that A2UI renderers (Lit, Angular, Flutter, etc.)
  expect to receive over WebSocket or other transports.

  ## v0.9 wire format

  All messages include `"version": "v0.9"` and are wrapped in JSON arrays.

  ## Message types

  - `update_components/1` — declares or updates components on a surface
  - `update_data_model/2` — updates data model values (triggers reactive bindings)
  - `create_surface/1` — signals the renderer to construct the UI from a root component
  - `delete_surface/1` — removes a surface

  ## Examples

      surface = A2UI.Builder.surface("status")
      |> A2UI.Builder.text("title", "Hello")

      A2UI.Encoder.update_components(surface)
      # => "[{\\"updateComponents\\":{\\"surfaceId\\":\\"status\\",\\"components\\":[...]},\\"version\\":\\"v0.9\\"}]"
  """

  @version "v0.9"

  @doc "Encodes an updateComponents message."
  @spec update_components(A2UI.Surface.t()) :: String.t()
  def update_components(%A2UI.Surface{} = surface) do
    %{
      "updateComponents" => %{
        "surfaceId" => surface.id,
        "components" => Enum.map(surface.components, &encode_component/1)
      },
      "version" => @version
    }
    |> wrap_array()
  end

  @doc "Encodes an updateDataModel message."
  @spec update_data_model(String.t(), map()) :: String.t()
  def update_data_model(surface_id, data) when is_binary(surface_id) and is_map(data) do
    %{
      "updateDataModel" => %{
        "surfaceId" => surface_id,
        "data" => data
      },
      "version" => @version
    }
    |> wrap_array()
  end

  @doc "Encodes a createSurface message."
  @spec create_surface(A2UI.Surface.t()) :: String.t()
  def create_surface(%A2UI.Surface{} = surface) do
    msg = %{
      "surfaceId" => surface.id,
      "rootComponentId" => surface.root_component_id || "root"
    }

    msg =
      case surface.catalog_id do
        nil -> msg
        catalog_id -> Map.put(msg, "catalogId", catalog_id)
      end

    %{"createSurface" => msg, "version" => @version}
    |> wrap_array()
  end

  @doc "Encodes a deleteSurface message."
  @spec delete_surface(String.t()) :: String.t()
  def delete_surface(surface_id) when is_binary(surface_id) do
    %{
      "deleteSurface" => %{"surfaceId" => surface_id},
      "version" => @version
    }
    |> wrap_array()
  end

  @doc """
  Encodes a full surface into a single JSON array containing all messages
  a renderer needs: updateComponents, optional updateDataModel, and createSurface.

  Returns a single JSON string (v0.9 message array).
  """
  @spec encode_surface(A2UI.Surface.t()) :: String.t()
  def encode_surface(%A2UI.Surface{} = surface) do
    messages = [
      %{
        "updateComponents" => %{
          "surfaceId" => surface.id,
          "components" => Enum.map(surface.components, &encode_component/1)
        },
        "version" => @version
      }
    ]

    messages =
      if map_size(surface.data) > 0 do
        messages ++
          [
            %{
              "updateDataModel" => %{
                "surfaceId" => surface.id,
                "data" => surface.data
              },
              "version" => @version
            }
          ]
      else
        messages
      end

    messages =
      case surface.root_component_id do
        nil ->
          messages

        root_id ->
          create = %{"surfaceId" => surface.id, "rootComponentId" => root_id}

          create =
            case surface.catalog_id do
              nil -> create
              catalog_id -> Map.put(create, "catalogId", catalog_id)
            end

          messages ++ [%{"createSurface" => create, "version" => @version}]
      end

    Jason.encode!(messages)
  end

  # --- Internal encoding ---

  @doc false
  def encode_component(%A2UI.Component{} = comp) do
    base = %{
      "id" => comp.id,
      "component" => encode_type_key(comp.type)
    }

    encode_properties_to_top_level(base, comp.properties)
  end

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
  defp encode_type_key({:custom, name}), do: Atom.to_string(name)

  defp encode_properties_to_top_level(base, props) when is_map(props) do
    Enum.reduce(props, base, fn {key, value}, acc ->
      Map.put(acc, encode_property_key(key), encode_property_value(value))
    end)
  end

  defp encode_property_key(key) when is_atom(key), do: to_camel_case(Atom.to_string(key))
  defp encode_property_key(key) when is_binary(key), do: key

  # v0.9: path-only → {"path": "..."}
  defp encode_property_value(%A2UI.BoundValue{literal: nil, path: path}) when not is_nil(path) do
    %{"path" => path}
  end

  # v0.9: literal-only → plain value (no literalString wrapper)
  defp encode_property_value(%A2UI.BoundValue{literal: lit, path: nil}) do
    lit
  end

  # v0.9: both set → use path (literal+path "both" mode removed in v0.9)
  defp encode_property_value(%A2UI.BoundValue{path: path}) when not is_nil(path) do
    %{"path" => path}
  end

  # v0.9: action → {"event": {"name": "...", "context": {...}}}
  defp encode_property_value(%A2UI.Action{} = action) do
    event = %{"name" => action.name}

    event =
      case action.context do
        nil -> event
        ctx when map_size(ctx) == 0 -> event
        ctx -> Map.put(event, "context", encode_context(ctx))
      end

    %{"event" => event}
  end

  defp encode_property_value(list) when is_list(list) do
    Enum.map(list, &encode_property_value/1)
  end

  defp encode_property_value(value) when is_binary(value), do: value
  defp encode_property_value(value) when is_number(value), do: value
  defp encode_property_value(value) when is_boolean(value), do: value
  defp encode_property_value(value) when is_atom(value), do: Atom.to_string(value)

  defp encode_context(ctx) when is_map(ctx) do
    Map.new(ctx, fn {key, value} ->
      {encode_property_key(key), encode_property_value(value)}
    end)
  end

  defp wrap_array(message) do
    Jason.encode!([message])
  end

  defp to_camel_case(string) do
    [first | rest] = String.split(string, "_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end
end
