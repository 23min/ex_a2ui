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

  @doc "Encodes an updateDataModel path-level upsert message."
  @spec update_data_model_path(String.t(), String.t(), term()) :: String.t()
  def update_data_model_path(surface_id, path, value)
      when is_binary(surface_id) and is_binary(path) do
    %{
      "updateDataModel" => %{
        "surfaceId" => surface_id,
        "path" => path,
        "value" => value
      },
      "version" => @version
    }
    |> wrap_array()
  end

  @doc "Encodes an updateDataModel path-level delete message."
  @spec delete_data_model_path(String.t(), String.t()) :: String.t()
  def delete_data_model_path(surface_id, path)
      when is_binary(surface_id) and is_binary(path) do
    %{
      "updateDataModel" => %{
        "surfaceId" => surface_id,
        "path" => path
      },
      "version" => @version
    }
    |> wrap_array()
  end

  @doc "Encodes a createSurface message."
  @spec create_surface(A2UI.Surface.t()) :: String.t()
  def create_surface(%A2UI.Surface{} = surface) do
    %{"createSurface" => build_create_surface_payload(surface), "version" => @version}
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

        _root_id ->
          messages ++
            [%{"createSurface" => build_create_surface_payload(surface), "version" => @version}]
      end

    Jason.encode!(messages)
  end

  # --- createSurface payload builder ---

  defp build_create_surface_payload(%A2UI.Surface{} = surface) do
    msg = %{
      "surfaceId" => surface.id,
      "rootComponentId" => surface.root_component_id || "root"
    }

    msg = maybe_put_field(msg, "catalogId", surface.catalog_id)
    msg = maybe_put_field(msg, "sendDataModel", surface.send_data_model)
    maybe_encode_theme(msg, surface.theme)
  end

  defp maybe_put_field(msg, _key, nil), do: msg
  defp maybe_put_field(msg, _key, false), do: msg
  defp maybe_put_field(msg, key, value), do: Map.put(msg, key, value)

  defp maybe_encode_theme(msg, nil), do: msg

  defp maybe_encode_theme(msg, %A2UI.Theme{} = theme) do
    theme_map = %{}

    theme_map =
      if theme.primary_color,
        do: Map.put(theme_map, "primaryColor", theme.primary_color),
        else: theme_map

    theme_map =
      if theme.icon_url,
        do: Map.put(theme_map, "iconUrl", theme.icon_url),
        else: theme_map

    theme_map =
      if theme.agent_display_name,
        do: Map.put(theme_map, "agentDisplayName", theme.agent_display_name),
        else: theme_map

    if map_size(theme_map) > 0, do: Map.put(msg, "theme", theme_map), else: msg
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

  # FunctionCall → {"call": "fn", "args": {...}, "returnType": "string"}
  defp encode_property_value(%A2UI.FunctionCall{} = fc) do
    result = %{"call" => fc.call}

    result =
      if map_size(fc.args) > 0 do
        encoded_args =
          Map.new(fc.args, fn {k, v} ->
            {k, encode_property_value(v)}
          end)

        Map.put(result, "args", encoded_args)
      else
        result
      end

    case fc.return_type do
      nil -> result
      rt -> Map.put(result, "returnType", rt)
    end
  end

  # TemplateChildList → {"path": "/items", "componentId": "item-template"}
  defp encode_property_value(%A2UI.TemplateChildList{} = tcl) do
    %{"path" => tcl.path, "componentId" => tcl.component_id}
  end

  # CheckRule → {"condition": <encoded>, "message": "..."}
  defp encode_property_value(%A2UI.CheckRule{} = cr) do
    %{
      "condition" => encode_property_value(cr.condition),
      "message" => cr.message
    }
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
