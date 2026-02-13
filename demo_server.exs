# Load demo providers
for file <- Path.wildcard("demo/*.ex") do
  Code.require_file(file)
end

defmodule DemoRouter do
  @behaviour A2UI.SurfaceProvider

  @demos %{
    "gallery" => Demo.ComponentGallery,
    "binding" => Demo.DataBinding,
    "form" => Demo.FormValidation,
    "push" => Demo.PushStreaming,
    "custom" => Demo.CustomComponent
  }

  @impl true
  def init(opts) do
    demo = get_in(opts, [:query_params, "demo"]) || "gallery"
    provider = Map.get(@demos, demo, Demo.ComponentGallery)

    case provider.init(opts) do
      {:ok, state} -> {:ok, %{provider: provider, inner: state}}
      error -> error
    end
  end

  @impl true
  def surface(%{provider: provider, inner: state}) do
    provider.surface(state)
  end

  @impl true
  def handle_action(action, %{provider: provider, inner: state} = wrapper) do
    case provider.handle_action(action, state) do
      {:noreply, new_state} -> {:noreply, %{wrapper | inner: new_state}}
      {:reply, surface, new_state} -> {:reply, surface, %{wrapper | inner: new_state}}
    end
  end

  @impl true
  def handle_info(msg, %{provider: provider, inner: state} = wrapper) do
    if function_exported?(provider, :handle_info, 2) do
      case provider.handle_info(msg, state) do
        {:noreply, new_state} ->
          {:noreply, %{wrapper | inner: new_state}}

        {:push_data, sid, data, new_state} ->
          {:push_data, sid, data, %{wrapper | inner: new_state}}

        {:push_surface, surface, new_state} ->
          {:push_surface, surface, %{wrapper | inner: new_state}}

        {:push_data_path, sid, path, value, new_state} ->
          {:push_data_path, sid, path, value, %{wrapper | inner: new_state}}

        {:delete_data_path, sid, path, new_state} ->
          {:delete_data_path, sid, path, %{wrapper | inner: new_state}}
      end
    else
      {:noreply, wrapper}
    end
  end

  @impl true
  def handle_error(error, %{provider: provider, inner: state} = wrapper) do
    if function_exported?(provider, :handle_error, 2) do
      case provider.handle_error(error, state) do
        {:noreply, new_state} -> {:noreply, %{wrapper | inner: new_state}}

        {:push_surface, surface, new_state} ->
          {:push_surface, surface, %{wrapper | inner: new_state}}
      end
    else
      {:noreply, wrapper}
    end
  end
end

IO.puts("Starting A2UI demo server on http://localhost:4000")
IO.puts("")
IO.puts("Available demos:")
IO.puts("  http://localhost:4000/?demo=gallery  — Component Gallery (default)")
IO.puts("  http://localhost:4000/?demo=binding  — Data Binding")
IO.puts("  http://localhost:4000/?demo=form     — Form Validation")
IO.puts("  http://localhost:4000/?demo=push     — Push Streaming")
IO.puts("  http://localhost:4000/?demo=custom   — Custom Components")
IO.puts("")
IO.puts("Press Ctrl+C to stop\n")

{:ok, _pid} = A2UI.Server.start_link(provider: DemoRouter, port: 4000)

Process.sleep(:infinity)
