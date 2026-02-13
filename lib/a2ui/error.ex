defmodule A2UI.Error do
  @moduledoc """
  Represents an error message received from an A2UI client.

  Clients send error messages when they encounter issues processing
  server messages — for example, validation failures on input components.

  ## Wire format

      [{"error": {"type": "VALIDATION_FAILED", "path": "/form/email", "message": "Invalid email"}}]

  ## Example

      %A2UI.Error{
        type: "VALIDATION_FAILED",
        path: "/form/email",
        message: "Invalid email"
      }
  """

  @type t :: %__MODULE__{
          type: String.t(),
          path: String.t() | nil,
          message: String.t() | nil
        }

  @enforce_keys [:type]
  defstruct [:type, :path, :message]

  @doc "Creates a new Error."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      type: Map.fetch!(attrs, :type),
      path: Map.get(attrs, :path),
      message: Map.get(attrs, :message)
    }
  end

  @doc "Creates a VALIDATION_FAILED error."
  @spec validation_failed(String.t(), String.t() | nil) :: t()
  def validation_failed(path, message \\ nil) when is_binary(path) do
    %__MODULE__{type: "VALIDATION_FAILED", path: path, message: message}
  end
end
