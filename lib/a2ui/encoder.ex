defmodule A2UI.Encoder do
  @moduledoc """
  Encodes A2UI Elixir structs into A2UI JSON wire format.

  Produces the JSON messages that A2UI renderers (Lit, Angular, Flutter, etc.)
  expect to receive over WebSocket or other transports.

  ## Message types

  - `surface_update/1` — declares or updates components on a surface
  - `data_model_update/2` — updates data model values (triggers reactive bindings)
  - `begin_rendering/2` — signals the renderer to construct the UI from a root component
  - `delete_surface/1` — removes a surface

  ## Examples

      surface = A2UI.Builder.surface("status")
      |> A2UI.Builder.text("title", "Hello")

      A2UI.Encoder.surface_update(surface)
      # => "{\"surfaceUpdate\":{\"surfaceId\":\"status\",\"components\":[...]}}"
  """

  @doc "Encodes a surface update message."
  @spec surface_update(A2UI.Surface.t()) :: String.t()
  def surface_update(%A2UI.Surface{} = surface) do
    %{
      "surfaceUpdate" => %{
        "surfaceId" => surface.id,
        "components" => Enum.map(surface.components, &encode_component/1)
      }
    }
    |> Jason.encode!()
  end

  @doc "Encodes a data model update message."
  @spec data_model_update(String.t(), map()) :: String.t()
  def data_model_update(surface_id, data) when is_binary(surface_id) and is_map(data) do
    %{
      "dataModelUpdate" => %{
        "surfaceId" => surface_id,
        "data" => data
      }
    }
    |> Jason.encode!()
  end

  @doc "Encodes a begin rendering message."
  @spec begin_rendering(String.t(), String.t(), keyword()) :: String.t()
  def begin_rendering(surface_id, root_component_id, opts \\ []) do
    msg = %{
      "surfaceId" => surface_id,
      "rootComponentId" => root_component_id
    }

    msg =
      case Keyword.get(opts, :catalog_id) do
        nil -> msg
        catalog_id -> Map.put(msg, "catalogId", catalog_id)
      end

    %{"beginRendering" => msg}
    |> Jason.encode!()
  end

  @doc "Encodes a delete surface message."
  @spec delete_surface(String.t()) :: String.t()
  def delete_surface(surface_id) when is_binary(surface_id) do
    %{"deleteSurface" => %{"surfaceId" => surface_id}}
    |> Jason.encode!()
  end

  @doc """
  Encodes a full surface into the sequence of messages a renderer needs:
  surface update, optional data model update, and begin rendering.

  Returns a list of JSON strings.
  """
  @spec encode_surface(A2UI.Surface.t()) :: [String.t()]
  def encode_surface(%A2UI.Surface{} = surface) do
    messages = [surface_update(surface)]

    messages =
      if map_size(surface.data) > 0 do
        messages ++ [data_model_update(surface.id, surface.data)]
      else
        messages
      end

    case surface.root_component_id do
      nil -> messages
      root_id -> messages ++ [begin_rendering(surface.id, root_id)]
    end
  end

  # --- Internal encoding ---

  @doc false
  def encode_component(%A2UI.Component{} = comp) do
    %{
      "id" => comp.id,
      "component" => %{
        encode_type_key(comp.type) => encode_properties(comp.properties)
      }
    }
  end

  defp encode_type_key(:text), do: "Text"
  defp encode_type_key(:button), do: "Button"
  defp encode_type_key(:text_field), do: "TextField"
  defp encode_type_key(:checkbox), do: "CheckBox"
  defp encode_type_key(:date_time_input), do: "DateTimeInput"
  defp encode_type_key(:slider), do: "Slider"
  defp encode_type_key(:multiple_choice), do: "MultipleChoice"
  defp encode_type_key(:image), do: "Image"
  defp encode_type_key(:icon), do: "Icon"
  defp encode_type_key(:video), do: "Video"
  defp encode_type_key(:divider), do: "Divider"
  defp encode_type_key(:row), do: "Row"
  defp encode_type_key(:column), do: "Column"
  defp encode_type_key(:list), do: "List"
  defp encode_type_key(:card), do: "Card"
  defp encode_type_key(:tabs), do: "Tabs"
  defp encode_type_key(:modal), do: "Modal"
  defp encode_type_key({:custom, name}), do: Atom.to_string(name)

  defp encode_properties(props) when is_map(props) do
    Map.new(props, fn {key, value} ->
      {encode_property_key(key), encode_property_value(value)}
    end)
  end

  defp encode_property_key(key) when is_atom(key), do: to_camel_case(Atom.to_string(key))
  defp encode_property_key(key) when is_binary(key), do: key

  defp encode_property_value(%A2UI.BoundValue{literal: nil, path: path}) when not is_nil(path) do
    %{"path" => path}
  end

  defp encode_property_value(%A2UI.BoundValue{literal: lit, path: nil}) do
    %{"literalString" => to_string(lit)}
  end

  defp encode_property_value(%A2UI.BoundValue{literal: lit, path: path}) do
    %{"literalString" => to_string(lit), "path" => path}
  end

  defp encode_property_value(%A2UI.Action{} = action) do
    encoded = %{"name" => action.name}

    case action.context do
      nil -> encoded
      ctx when map_size(ctx) == 0 -> encoded
      ctx -> Map.put(encoded, "context", encode_properties(ctx))
    end
  end

  defp encode_property_value(list) when is_list(list) do
    Enum.map(list, &encode_property_value/1)
  end

  defp encode_property_value(value) when is_binary(value), do: value
  defp encode_property_value(value) when is_number(value), do: value
  defp encode_property_value(value) when is_boolean(value), do: value
  defp encode_property_value(value) when is_atom(value), do: Atom.to_string(value)

  defp to_camel_case(string) do
    [first | rest] = String.split(string, "_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end
end
