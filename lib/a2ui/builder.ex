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

  alias A2UI.{BoundValue, Action, CheckRule, Component, FunctionCall, TemplateChildList, Surface}

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

  @doc "Sets the theme on the surface."
  @spec theme(Surface.t(), keyword()) :: Surface.t()
  def theme(%Surface{} = s, opts) when is_list(opts) do
    %{s | theme: A2UI.Theme.new(opts)}
  end

  @doc "Enables or disables the sendDataModel flag on the surface."
  @spec send_data_model(Surface.t(), boolean()) :: Surface.t()
  def send_data_model(%Surface{} = s, flag \\ true) when is_boolean(flag) do
    %{s | send_data_model: flag}
  end

  @doc "Sets the catalog ID on the surface."
  @spec catalog_id(Surface.t(), String.t() | A2UI.Catalog.t()) :: Surface.t()
  def catalog_id(%Surface{} = s, %A2UI.Catalog{id: id}), do: %{s | catalog_id: id}
  def catalog_id(%Surface{} = s, id) when is_binary(id), do: %{s | catalog_id: id}

  # --- Display components ---

  @doc """
  Adds a Text component.

  ## Options

  - `bind:` — data model path to bind the text value to

  ## Examples

      UI.text(surface, "greeting", "Hello!")
      UI.text(surface, "name", bind: "/user/name")
  """
  @spec text(Surface.t(), String.t(), String.t() | FunctionCall.t() | keyword()) :: Surface.t()
  def text(%Surface{} = s, id, text) when is_binary(text) do
    add(s, id, :text, %{text: BoundValue.literal(text)})
  end

  def text(%Surface{} = s, id, %FunctionCall{} = fc) do
    add(s, id, :text, %{text: fc})
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

  @doc """
  Adds an Icon component.

  ## Options

  - `bind:` — data model path for the icon name
  """
  @spec icon(Surface.t(), String.t(), String.t() | keyword()) :: Surface.t()
  def icon(%Surface{} = s, id, name) when is_binary(name) do
    add(s, id, :icon, %{icon: BoundValue.literal(name)})
  end

  def icon(%Surface{} = s, id, opts) when is_list(opts) do
    value = resolve_bound_value(opts[:bind], opts[:icon])
    add(s, id, :icon, %{icon: value})
  end

  @doc """
  Adds a Video component.

  ## Options

  - `bind:` — data model path for the video source
  - `alt:` — alt text
  """
  @spec video(Surface.t(), String.t(), String.t() | keyword()) :: Surface.t()
  def video(%Surface{} = s, id, src) when is_binary(src) do
    add(s, id, :video, %{src: BoundValue.literal(src)})
  end

  def video(%Surface{} = s, id, opts) when is_list(opts) do
    props =
      %{src: resolve_bound_value(opts[:bind], opts[:src])}
      |> maybe_put(:alt, opts[:alt])

    add(s, id, :video, props)
  end

  @doc """
  Adds an AudioPlayer component.

  ## Options

  - `bind:` — data model path for the audio source
  """
  @spec audio_player(Surface.t(), String.t(), String.t() | keyword()) :: Surface.t()
  def audio_player(%Surface{} = s, id, src) when is_binary(src) do
    add(s, id, :audio_player, %{src: BoundValue.literal(src)})
  end

  def audio_player(%Surface{} = s, id, opts) when is_list(opts) do
    props = %{src: resolve_bound_value(opts[:bind], opts[:src])}
    add(s, id, :audio_player, props)
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
  - `checks:` — list of `CheckRule` validation rules
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

    props = maybe_put(props, :checks, opts[:checks])

    add(s, id, :text_field, props)
  end

  @doc """
  Adds a CheckBox component.

  ## Options

  - `label:` — checkbox label
  - `bind:` — data model path for checked state
  - `action:` — action name triggered on toggle
  - `checks:` — list of `CheckRule` validation rules
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

    props = maybe_put(props, :checks, opts[:checks])

    add(s, id, :checkbox, props)
  end

  @doc """
  Adds a DateTimeInput component.

  ## Options

  - `bind:` — data model path for the value
  - `action:` — action name triggered on change
  - `checks:` — list of `CheckRule` validation rules
  """
  @spec date_time_input(Surface.t(), String.t(), keyword()) :: Surface.t()
  def date_time_input(%Surface{} = s, id, opts \\ []) do
    props = %{}

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

    props = maybe_put(props, :checks, opts[:checks])

    add(s, id, :date_time_input, props)
  end

  @doc """
  Adds a ChoicePicker component.

  ## Options

  - `options:` — list of choice options (maps with label/value)
  - `bind:` — data model path for the selected value
  - `action:` — action name triggered on selection
  - `checks:` — list of `CheckRule` validation rules
  """
  @spec choice_picker(Surface.t(), String.t(), keyword()) :: Surface.t()
  def choice_picker(%Surface{} = s, id, opts \\ []) do
    props = %{}

    props =
      case opts[:bind] do
        nil -> props
        path -> Map.put(props, :value, BoundValue.bind(path))
      end

    props = maybe_put(props, :options, opts[:options])

    props =
      case opts[:action] do
        nil -> props
        name -> Map.put(props, :action, Action.new(name))
      end

    props = maybe_put(props, :checks, opts[:checks])

    add(s, id, :choice_picker, props)
  end

  @doc """
  Adds a Slider component.

  ## Options

  - `min:` — minimum value
  - `max:` — maximum value
  - `bind:` — data model path for current value
  - `action:` — action name triggered on change
  - `checks:` — list of `CheckRule` validation rules
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

    props = maybe_put(props, :checks, opts[:checks])

    add(s, id, :slider, props)
  end

  # --- Container components ---

  @doc """
  Adds a Card component.

  ## Options

  - `children:` — list of child component IDs or a `TemplateChildList`
  - `title:` — card title text

  ## Examples

      UI.card(surface, "main", children: ["title", "body", "actions"])
      UI.card(surface, "list", children: UI.template_children("/items", "item-tpl"))
  """
  @spec card(Surface.t(), String.t(), keyword()) :: Surface.t()
  def card(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put_children(props, opts[:children])
    props = maybe_put_literal(props, :title, opts[:title])
    add(s, id, :card, props)
  end

  @doc """
  Adds a Row component (horizontal layout).

  ## Options

  - `children:` — list of child component IDs or a `TemplateChildList`
  """
  @spec row(Surface.t(), String.t(), keyword()) :: Surface.t()
  def row(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put_children(props, opts[:children])
    add(s, id, :row, props)
  end

  @doc """
  Adds a Column component (vertical layout).

  ## Options

  - `children:` — list of child component IDs or a `TemplateChildList`
  """
  @spec column(Surface.t(), String.t(), keyword()) :: Surface.t()
  def column(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put_children(props, opts[:children])
    add(s, id, :column, props)
  end

  @doc """
  Adds a Modal component.

  ## Options

  - `children:` — list of child component IDs or a `TemplateChildList`
  - `title:` — modal title
  """
  @spec modal(Surface.t(), String.t(), keyword()) :: Surface.t()
  def modal(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put_children(props, opts[:children])
    props = maybe_put_literal(props, :title, opts[:title])
    add(s, id, :modal, props)
  end

  @doc """
  Adds a List component (scrollable list with item template).

  ## Options

  - `children:` — list of child component IDs or a `TemplateChildList`
  """
  @spec list(Surface.t(), String.t(), keyword()) :: Surface.t()
  def list(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put_children(props, opts[:children])
    add(s, id, :list, props)
  end

  @doc """
  Adds a Tabs component (tabbed sections).

  ## Options

  - `children:` — list of child component IDs or a `TemplateChildList`
  - `title:` — tabs title
  """
  @spec tabs(Surface.t(), String.t(), keyword()) :: Surface.t()
  def tabs(%Surface{} = s, id, opts \\ []) do
    props = %{}
    props = maybe_put_children(props, opts[:children])
    props = maybe_put_literal(props, :title, opts[:title])
    add(s, id, :tabs, props)
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

  # --- FunctionCall helpers ---

  @doc "Creates a `formatString` FunctionCall for use as a dynamic value."
  @spec format_string(String.t()) :: FunctionCall.t()
  def format_string(template), do: FunctionCall.format_string(template)

  @doc "Creates an `openUrl` FunctionCall for use as a dynamic value."
  @spec open_url(String.t()) :: FunctionCall.t()
  def open_url(url), do: FunctionCall.open_url(url)

  @doc "Creates a `numeric` validation FunctionCall."
  @spec numeric(term()) :: FunctionCall.t()
  def numeric(value_ref), do: FunctionCall.numeric(value_ref)

  @doc "Creates an `email` validation FunctionCall."
  @spec email(term()) :: FunctionCall.t()
  def email(value_ref), do: FunctionCall.email(value_ref)

  @doc "Creates a `formatNumber` FunctionCall."
  @spec format_number(term()) :: FunctionCall.t()
  def format_number(value_ref), do: FunctionCall.format_number(value_ref)

  @doc "Creates a `formatCurrency` FunctionCall."
  @spec format_currency(term(), String.t()) :: FunctionCall.t()
  def format_currency(value_ref, currency_code),
    do: FunctionCall.format_currency(value_ref, currency_code)

  @doc "Creates a `formatDate` FunctionCall."
  @spec format_date(term(), String.t()) :: FunctionCall.t()
  def format_date(value_ref, format), do: FunctionCall.format_date(value_ref, format)

  @doc "Creates a `pluralize` FunctionCall."
  @spec pluralize(term(), term(), term()) :: FunctionCall.t()
  def pluralize(count, singular, plural), do: FunctionCall.pluralize(count, singular, plural)

  @doc "Creates an `and` logic FunctionCall."
  @spec fn_and(list()) :: FunctionCall.t()
  def fn_and(conditions), do: FunctionCall.fn_and(conditions)

  @doc "Creates an `or` logic FunctionCall."
  @spec fn_or(list()) :: FunctionCall.t()
  def fn_or(conditions), do: FunctionCall.fn_or(conditions)

  @doc "Creates a `not` logic FunctionCall."
  @spec fn_not(term()) :: FunctionCall.t()
  def fn_not(condition), do: FunctionCall.fn_not(condition)

  # --- TemplateChildList helpers ---

  @doc "Creates a `TemplateChildList` for data-driven children."
  @spec template_children(String.t(), String.t()) :: TemplateChildList.t()
  def template_children(path, component_id),
    do: TemplateChildList.new(path, component_id)

  # --- CheckRule helpers ---

  @doc "Creates a `required` check rule bound to a data model path."
  @spec required_check(String.t(), String.t()) :: CheckRule.t()
  def required_check(bind_path, message \\ "This field is required") do
    CheckRule.required(BoundValue.bind(bind_path), message)
  end

  @doc "Creates a `max_length` check rule bound to a data model path."
  @spec max_length_check(String.t(), integer(), String.t()) :: CheckRule.t()
  def max_length_check(bind_path, max, message \\ "Too long") do
    CheckRule.max_length(BoundValue.bind(bind_path), max, message)
  end

  @doc "Creates a `regex` check rule bound to a data model path."
  @spec regex_check(String.t(), String.t(), String.t()) :: CheckRule.t()
  def regex_check(bind_path, pattern, message) do
    CheckRule.regex(BoundValue.bind(bind_path), pattern, message)
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

  defp maybe_put_children(map, nil), do: map
  defp maybe_put_children(map, %TemplateChildList{} = tcl), do: Map.put(map, :children, tcl)

  defp maybe_put_children(map, children) when is_list(children),
    do: Map.put(map, :children, children)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_literal(map, _key, nil), do: map
  defp maybe_put_literal(map, key, value), do: Map.put(map, key, BoundValue.literal(value))
end
