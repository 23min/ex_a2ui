defmodule A2UI.BoundValue do
  @moduledoc """
  A value that can be a literal, a data model binding (JSON Pointer path), or both.

  When both `literal` and `path` are set, the literal provides the initial value
  and the path creates a reactive binding — the component updates automatically
  when the data model changes at that path.

  ## Examples

      # Static value
      %A2UI.BoundValue{literal: "Hello"}

      # Bound to data model
      %A2UI.BoundValue{path: "/user/name"}

      # Initial value with binding
      %A2UI.BoundValue{literal: "loading...", path: "/user/name"}
  """

  @type t :: %__MODULE__{
          literal: term() | nil,
          path: String.t() | nil
        }

  @enforce_keys []
  defstruct [:literal, :path]

  @doc "Creates a BoundValue with a literal value."
  @spec literal(term()) :: t()
  def literal(value), do: %__MODULE__{literal: value}

  @doc "Creates a BoundValue bound to a data model path."
  @spec bind(String.t()) :: t()
  def bind(path) when is_binary(path), do: %__MODULE__{path: path}

  @doc "Creates a BoundValue with both a literal and a binding path."
  @spec bind(String.t(), term()) :: t()
  def bind(path, literal) when is_binary(path),
    do: %__MODULE__{path: path, literal: literal}
end
