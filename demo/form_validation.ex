defmodule Demo.FormValidation do
  @behaviour A2UI.SurfaceProvider

  alias A2UI.Builder, as: UI

  @impl true
  def init(_opts), do: {:ok, %{submitted: false, errors: []}}

  @impl true
  def surface(state) do
    s =
      UI.surface("form-validation")
      |> UI.theme(agent_display_name: "Form Validation Demo")
      # Email field with checks
      |> UI.text("email-label", "Email:")
      |> UI.text_field("email",
        bind: "/form/email",
        placeholder: "user@example.com",
        action: "field_changed",
        checks: [
          UI.required_check("/form/email", "Email is required"),
          UI.regex_check("/form/email", "^[^@]+@[^@]+\\.[^@]+$", "Must be a valid email")
        ]
      )
      |> UI.row("email-row", children: ["email-label", "email"])
      # Username field with length check
      |> UI.text("user-label", "Username:")
      |> UI.text_field("username",
        bind: "/form/username",
        placeholder: "3-20 characters",
        action: "field_changed",
        checks: [
          UI.required_check("/form/username", "Username is required"),
          UI.max_length_check("/form/username", 20, "Max 20 characters")
        ]
      )
      |> UI.row("user-row", children: ["user-label", "username"])
      # Terms checkbox
      |> UI.checkbox("terms", label: "I accept the terms", bind: "/form/terms", action: "field_changed")
      # Submit
      |> UI.button("submit", "Submit", action: "submit")
      |> UI.divider("div")

    s =
      if state.submitted do
        UI.text(s, "status", "Form submitted successfully!")
      else
        UI.text(s, "status", "Fill out the form above.")
      end

    s
    |> UI.column("body", children: ["email-row", "user-row", "terms", "div", "submit", "status"])
    |> UI.card("main", title: "Form with Validation", children: ["body"])
    |> UI.root("main")
    |> UI.data("/form/email", "")
    |> UI.data("/form/username", "")
    |> UI.data("/form/terms", false)
  end

  @impl true
  def handle_action(%A2UI.Action{name: "submit"}, state) do
    new_state = %{state | submitted: true}
    {:reply, surface(new_state), new_state}
  end

  def handle_action(_, state), do: {:noreply, state}

  @impl true
  def handle_error(%A2UI.Error{} = error, state) do
    new_state = %{state | errors: [error | state.errors]}
    {:noreply, new_state}
  end
end
