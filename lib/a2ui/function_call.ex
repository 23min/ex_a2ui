defmodule A2UI.FunctionCall do
  @moduledoc """
  A client-evaluated function call used as a dynamic value in component properties.

  The server emits FunctionCall values; the client evaluates them.
  This enables computed values like formatted strings, validation conditions,
  and client-side navigation without server round-trips.

  ## Wire format

      {"call": "formatString", "args": {"template": "Hello ${/name}"}, "returnType": "string"}

  ## Standard functions

  A2UI v0.9 defines 14 standard functions:

  - **Validation:** required, regex, length, numeric, email
  - **Formatting:** formatString, formatNumber, formatCurrency, formatDate, pluralize
  - **Logic:** and, or, not
  - **Actions:** openUrl

  ## Examples

      # Format a string with data bindings
      %A2UI.FunctionCall{
        call: "formatString",
        args: %{"template" => "Hello ${/user/name}"},
        return_type: "string"
      }

      # Validate a field is not empty
      A2UI.FunctionCall.required(%A2UI.BoundValue{path: "/form/name"})
  """

  @type t :: %__MODULE__{
          call: String.t(),
          args: map(),
          return_type: String.t() | nil
        }

  @enforce_keys [:call]
  defstruct [:call, :return_type, args: %{}]

  @standard_functions ~w(
    required regex length numeric email
    formatString formatNumber formatCurrency formatDate pluralize
    and or not openUrl
  )

  @doc "Returns the list of 14 standard A2UI function names."
  @spec standard_functions() :: [String.t()]
  def standard_functions, do: @standard_functions

  @doc "Creates a FunctionCall."
  @spec new(String.t(), map(), String.t() | nil) :: t()
  def new(call, args \\ %{}, return_type \\ nil)

  def new(call, args, return_type) when is_binary(call) and is_map(args) do
    %__MODULE__{call: call, args: args, return_type: return_type}
  end

  @doc "Creates a `formatString` function call with a template."
  @spec format_string(String.t()) :: t()
  def format_string(template) when is_binary(template) do
    %__MODULE__{call: "formatString", args: %{"template" => template}, return_type: "string"}
  end

  @doc "Creates an `openUrl` function call."
  @spec open_url(String.t()) :: t()
  def open_url(url) when is_binary(url) do
    %__MODULE__{call: "openUrl", args: %{"url" => url}}
  end

  @doc "Creates a `required` validation function call."
  @spec required(term()) :: t()
  def required(value_ref) do
    %__MODULE__{call: "required", args: %{"value" => value_ref}, return_type: "boolean"}
  end

  @doc "Creates a `regex` validation function call."
  @spec regex(term(), String.t()) :: t()
  def regex(value_ref, pattern) when is_binary(pattern) do
    %__MODULE__{
      call: "regex",
      args: %{"value" => value_ref, "pattern" => pattern},
      return_type: "boolean"
    }
  end

  @doc "Creates a `length` validation function call."
  @spec length(term(), keyword()) :: t()
  def length(value_ref, opts) when is_list(opts) do
    args = %{"value" => value_ref}
    args = if opts[:min], do: Map.put(args, "min", opts[:min]), else: args
    args = if opts[:max], do: Map.put(args, "max", opts[:max]), else: args
    %__MODULE__{call: "length", args: args, return_type: "boolean"}
  end
end
