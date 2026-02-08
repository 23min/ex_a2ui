defmodule A2UI.Decoder do
  @moduledoc """
  Decodes incoming A2UI messages (primarily `userAction`) from JSON.

  Used to parse messages received from the client-side renderer when
  users interact with A2UI surfaces.

  ## Examples

      json = ~s({"userAction":{"action":{"name":"refresh"}}})
      {:ok, {:user_action, action}} = A2UI.Decoder.decode(json)
      action.name
      # => "refresh"
  """

  @doc """
  Decodes an incoming A2UI JSON message.

  Returns `{:ok, message}` or `{:error, reason}`.
  """
  @spec decode(String.t()) :: {:ok, term()} | {:error, term()}
  def decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, %{"userAction" => payload}} -> decode_user_action(payload)
      {:ok, other} -> {:error, {:unknown_message, other}}
      {:error, reason} -> {:error, {:json_parse_error, reason}}
    end
  end

  defp decode_user_action(%{"action" => action_data}) do
    action = %A2UI.Action{
      name: Map.fetch!(action_data, "name"),
      context: decode_context(Map.get(action_data, "context"))
    }

    {:ok, {:user_action, action}}
  end

  defp decode_user_action(other), do: {:error, {:invalid_user_action, other}}

  defp decode_context(nil), do: nil
  defp decode_context(ctx) when is_map(ctx), do: ctx
end
