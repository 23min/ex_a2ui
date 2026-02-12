defmodule A2UI.Theme do
  @moduledoc """
  Theme configuration for an A2UI surface.

  Applied via the `createSurface` message. All fields are optional.

  ## Wire format

      {"primaryColor": "#00BFFF", "iconUrl": "https://...", "agentDisplayName": "Assistant"}

  ## Examples

      %A2UI.Theme{
        primary_color: "#00BFFF",
        icon_url: "https://example.com/logo.png",
        agent_display_name: "My Agent"
      }
  """

  @type t :: %__MODULE__{
          primary_color: String.t() | nil,
          icon_url: String.t() | nil,
          agent_display_name: String.t() | nil
        }

  defstruct [:primary_color, :icon_url, :agent_display_name]

  @doc "Creates a theme from keyword options."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      primary_color: opts[:primary_color],
      icon_url: opts[:icon_url],
      agent_display_name: opts[:agent_display_name]
    }
  end
end
