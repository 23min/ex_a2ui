defmodule A2UI.Builder do
  @moduledoc """
  Pipe-friendly convenience functions for building A2UI surfaces.

  The Builder is the recommended way to construct surfaces. Each function
  returns the surface with the component added, enabling clean pipelines:

      alias A2UI.Builder, as: UI

      UI.surface("dashboard")
      |> UI.text("title", "My Dashboard")
      |> UI.button("refresh", "Refresh", action: "do_refresh")
      |> UI.card("main", children: ["title", "refresh"])
      |> UI.root("main")

  ## Binding to data model

  Use the `bind:` option to bind a component property to the data model:

      UI.surface("status")
      |> UI.text("health", bind: "/system/health")
      |> UI.data("/system/health", "operational")

  The text component will reactively update when the data at
  `/system/health` changes.
  """

  alias A2UI.{BoundValue, Action, Component, Surface}

  # --- Surface ---

  @doc "Creates a new empty surface with the given ID."
  @spec surface(String.t()) :: Surface.t()
  def surface(id), do: Surface.new(id)

  @doc "Sets the root component ID. The renderer starts building from this component."
  @spec root(Surface.t(), String.t()) :: Surface.t()
  def root(%Surface{} = s, component_id), do: Surface.set_root(s, component_id)

  @doc "Sets a data model value on the surface."
  @spec data(Surface.t(), String.t(), term()) :: Surface.t()
  def data(%Surface{} = s, path, value), do: Surface.put_data(s, path, value)

  # --- Display components ---

  @doc """
  Adds a Text component.

  ## Options

  - `bind:` — data model path to bind the text value to

  ## Examples

      UI.text(surface, "greeting", "Hello!")
      UI.text(surface, "name", bind: "/user/name")
  """
  @spec text(Surface.t(), String.t(), String.t() | keyword()) :: Surface.t()
  def text(%Surface{} = s, id, text) when is_binary(text) do
    add(s, id, :text, %{text: BoundValue.literal(text)})
  end

  def text(%Surface{} = s, id, opts) when is_list(opts) do
    value = resolve_bound_value(opts[:bind], opts[:text])
    add(s, id, :text, %{text: value})
  end

  @doc """
  Adds an Image component.

  ## Options

  - `alt:` — alt text
  - `bind:` — data model path for the image source
  """
  @spec image(Surface.t(), String.t(), String.t() | keyword()) :: Surface.t()
  def image(%Surface{} = s, id, src) when is_binary(src) do
    add(s, id, :image, %{src: BoundValue.literal(src)})
  end

  def image(%Surface{} = s, id, opts) when is_list(opts) do
    props =
      %{src: resolve_bound_value(opts[:bind], opts[:src])}
      |> maybe_put(:alt, opts[:alt])

    add(s, id, :image, props)
  end

  @doc "Adds a Divider component."
  @spec divider(Surface.t(), String.t()) :: Surface.t()
  def divider(%Surface{} = s, id), do: add(s, id, :divider, %{})

  # --- Interactive components ---

  @doc """
  Adds a Button component.

  ## Options

  - `action:` — action name (string) triggered on click
  - `bind:` — data model path for the button label

  ## Examples

      UI.button(surface, "submit", "Submit", action: "submit_form")
  """
  @spec button(Surface.t(), String.t(), String.t(), keyword()) :: Surface.t()
  def button(%Surface{} = s, id, label, opts \\ []) do
    props = %{label: BoundValue.literal(label)}

    props =
      case opts[:action] do
        nil -> props
        name when is_binary(name) -> Map.put(props, :action, Action.new(name))
        %Action{} = action -> Map.put(props, :action, action)
      end

    add(s, id, :button, props)
  end

  @doc """
  Adds a TextField component.

  ## Options

  - `placeholder:` — placeholder text
  - `bind:` — data model path for the field value
  - `action:` — action name triggered on change/submit
  """
  @spec text_field(Surface.t(), String.t(), keyword()) :: Surface.t()
  def text_field(%Surface{} = s, id, opts \\ []) do
    props = %{}

    props =
      case opts[:bind] do
        nil -> props
        path -> Map.put(props, :value, BoundValue.bind(path))
      end

    props = maybe_put_literal(props, :placeholder, opts[:placeholder])

    props =
      case opts[:action] do
        nil -> props
        name -> Map.put(props, :action, Action.new(name))
      end

    add(s, id, :text_field, props)
  end

  @doc """
  Adds a CheckBox component.

  ## Options

  - `label:` — checkbox label
  - `bind:` — data model path for checked state
  - `action:` — action name triggered on toggle
  """
  @spec checkbox(Surface.t(), String.t(), keyword()) :: Surface.t()
  def checkbox(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put_literal(props, :label, opts[:label])

    props =
      case opts[:bind] do
        nil -> props
        path -> Map.put(props, :checked, BoundValue.bind(path))
      end

    props =
      case opts[:action] do
        nil -> props
        name -> Map.put(props, :action, Action.new(name))
      end

    add(s, id, :checkbox, props)
  end

  @doc """
  Adds a Slider component.

  ## Options

  - `min:` — minimum value
  - `max:` — maximum value
  - `bind:` — data model path for current value
  - `action:` — action name triggered on change
  """
  @spec slider(Surface.t(), String.t(), keyword()) :: Surface.t()
  def slider(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put_literal(props, :min, opts[:min])
    props = maybe_put_literal(props, :max, opts[:max])

    props =
      case opts[:bind] do
        nil -> props
        path -> Map.put(props, :value, BoundValue.bind(path))
      end

    props =
      case opts[:action] do
        nil -> props
        name -> Map.put(props, :action, Action.new(name))
      end

    add(s, id, :slider, props)
  end

  # --- Container components ---

  @doc """
  Adds a Card component.

  ## Options

  - `children:` — list of child component IDs
  - `title:` — card title text

  ## Examples

      UI.card(surface, "main", children: ["title", "body", "actions"])
  """
  @spec card(Surface.t(), String.t(), keyword()) :: Surface.t()
  def card(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put(props, :children, opts[:children])
    props = maybe_put_literal(props, :title, opts[:title])
    add(s, id, :card, props)
  end

  @doc """
  Adds a Row component (horizontal layout).

  ## Options

  - `children:` — list of child component IDs
  """
  @spec row(Surface.t(), String.t(), keyword()) :: Surface.t()
  def row(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put(props, :children, opts[:children])
    add(s, id, :row, props)
  end

  @doc """
  Adds a Column component (vertical layout).

  ## Options

  - `children:` — list of child component IDs
  """
  @spec column(Surface.t(), String.t(), keyword()) :: Surface.t()
  def column(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put(props, :children, opts[:children])
    add(s, id, :column, props)
  end

  @doc """
  Adds a Modal component.

  ## Options

  - `children:` — list of child component IDs
  - `title:` — modal title
  """
  @spec modal(Surface.t(), String.t(), keyword()) :: Surface.t()
  def modal(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put(props, :children, opts[:children])
    props = maybe_put_literal(props, :title, opts[:title])
    add(s, id, :modal, props)
  end

  # --- Custom components ---

  @doc """
  Adds a custom component with an arbitrary type name.

  Use this for domain-specific components registered in the client's catalog.

  ## Examples

      UI.custom(surface, :graph, "arch-graph",
        nodes: A2UI.BoundValue.bind("/graph/nodes"),
        edges: A2UI.BoundValue.bind("/graph/edges")
      )
  """
  @spec custom(Surface.t(), atom(), String.t(), keyword()) :: Surface.t()
  def custom(%Surface{} = s, type, id, props \\ []) when is_atom(type) do
    add(s, id, {:custom, type}, Map.new(props))
  end

  # --- Internal helpers ---

  defp add(%Surface{} = s, id, type, properties) do
    component = %Component{id: id, type: type, properties: properties}
    Surface.add_component(s, component)
  end

  defp resolve_bound_value(nil, nil), do: BoundValue.literal("")
  defp resolve_bound_value(nil, text), do: BoundValue.literal(text)
  defp resolve_bound_value(path, nil), do: BoundValue.bind(path)
  defp resolve_bound_value(path, text), do: BoundValue.bind(path, text)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_literal(map, _key, nil), do: map
  defp maybe_put_literal(map, key, value), do: Map.put(map, key, BoundValue.literal(value))
end
