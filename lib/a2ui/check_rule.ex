defmodule A2UI.CheckRule do
  @moduledoc """
  A validation rule for input components.

  Each check has a `condition` (a DynamicBoolean — literal boolean, path binding,
  or FunctionCall that returns boolean) and a `message` string displayed when
  validation fails (condition evaluates to `false`).

  ## Wire format

      {"condition": {"call": "required", "args": {"value": {"path": "/form/name"}}}, "message": "Name is required"}

  ## Examples

      # Using convenience constructor
      A2UI.CheckRule.required(A2UI.BoundValue.bind("/form/name"))

      # Manual construction
      %A2UI.CheckRule{
        condition: A2UI.FunctionCall.regex(A2UI.BoundValue.bind("/form/zip"), "^\\\\d{5}$"),
        message: "Must be a 5-digit zip code"
      }
  """

  @type condition :: boolean() | A2UI.BoundValue.t() | A2UI.FunctionCall.t()

  @type t :: %__MODULE__{
          condition: condition(),
          message: String.t()
        }

  @enforce_keys [:condition, :message]
  defstruct [:condition, :message]

  @doc "Creates a check rule."
  @spec new(condition(), String.t()) :: t()
  def new(condition, message) when is_binary(message) do
    %__MODULE__{condition: condition, message: message}
  end

  @doc "Creates a `required` check rule."
  @spec required(term(), String.t()) :: t()
  def required(value_ref, message \\ "This field is required") do
    condition = A2UI.FunctionCall.new("required", %{"value" => value_ref}, "boolean")
    %__MODULE__{condition: condition, message: message}
  end

  @doc "Creates a `regex` check rule."
  @spec regex(term(), String.t(), String.t()) :: t()
  def regex(value_ref, pattern, message) when is_binary(pattern) and is_binary(message) do
    condition =
      A2UI.FunctionCall.new(
        "regex",
        %{"value" => value_ref, "pattern" => pattern},
        "boolean"
      )

    %__MODULE__{condition: condition, message: message}
  end

  @doc "Creates a `length` check rule with a max constraint."
  @spec max_length(term(), integer(), String.t()) :: t()
  def max_length(value_ref, max, message \\ "Too long") when is_integer(max) do
    condition = A2UI.FunctionCall.new("length", %{"value" => value_ref, "max" => max}, "boolean")
    %__MODULE__{condition: condition, message: message}
  end
end
