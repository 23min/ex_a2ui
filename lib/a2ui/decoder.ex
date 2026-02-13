defmodule A2UI.Decoder do
  @moduledoc """
  Decodes incoming A2UI v0.9 messages from JSON.

  Handles the v0.9 `action` message format (renamed from v0.8 `userAction`).
  Messages may arrive as JSON arrays (v0.9 spec) or individual objects.

  ## Examples

      json = ~s([{"action":{"event":{"name":"refresh"},"surfaceId":"s1"}}])
      {:ok, [{:action, action, metadata}]} = A2UI.Decoder.decode(json)
      action.name
      # => "refresh"
  """

  @doc """
  Decodes an incoming A2UI JSON message.

  Accepts both v0.9 array format and single-object format.
  Returns `{:ok, messages}` (list) or `{:error, reason}`.
  """
  @spec decode(String.t()) :: {:ok, [term()]} | {:error, term()}
  def decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, messages} when is_list(messages) ->
        decode_messages(messages)

      {:ok, %{} = message} ->
        decode_messages([message])

      {:error, reason} ->
        {:error, {:json_parse_error, reason}}
    end
  end

  defp decode_messages(messages) do
    results =
      Enum.reduce_while(messages, [], fn message, acc ->
        case decode_message(message) do
          {:ok, decoded} -> {:cont, [decoded | acc]}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case results do
      {:error, _} = error -> error
      decoded -> {:ok, Enum.reverse(decoded)}
    end
  end

  defp decode_message(%{"action" => payload}) do
    decode_action(payload)
  end

  defp decode_message(%{"error" => payload}) do
    decode_error(payload)
  end

  defp decode_message(other) do
    {:error, {:unknown_message, other}}
  end

  defp decode_action(%{"event" => event_data} = payload) do
    action = %A2UI.Action{
      name: Map.fetch!(event_data, "name"),
      context: decode_context(Map.get(event_data, "context"))
    }

    metadata = %{
      surface_id: Map.get(payload, "surfaceId"),
      source_component_id: Map.get(payload, "sourceComponentId"),
      timestamp: Map.get(payload, "timestamp")
    }

    {:ok, {:action, action, metadata}}
  end

  # Fallback: accept bare action for simpler clients
  defp decode_action(%{"name" => _name} = action_data) do
    action = %A2UI.Action{
      name: Map.fetch!(action_data, "name"),
      context: decode_context(Map.get(action_data, "context"))
    }

    {:ok, {:action, action, %{}}}
  end

  defp decode_action(other), do: {:error, {:invalid_action, other}}

  defp decode_context(nil), do: nil
  defp decode_context(ctx) when is_map(ctx), do: ctx

  defp decode_error(%{"type" => type} = payload) do
    error = %A2UI.Error{
      type: type,
      path: Map.get(payload, "path"),
      message: Map.get(payload, "message")
    }

    metadata = %{
      surface_id: Map.get(payload, "surfaceId")
    }

    {:ok, {:error, error, metadata}}
  end

  defp decode_error(other), do: {:error, {:invalid_error, other}}
end
