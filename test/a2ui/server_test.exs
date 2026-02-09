defmodule A2UI.ServerTest do
  use ExUnit.Case, async: true

  defmodule DummyProvider do
    @behaviour A2UI.SurfaceProvider

    @impl true
    def init(_), do: {:ok, %{}}

    @impl true
    def surface(_), do: A2UI.Builder.surface("test")

    @impl true
    def handle_action(_, s), do: {:noreply, s}
  end

  describe "child_spec/1" do
    test "returns valid child spec with required options" do
      spec = A2UI.Server.child_spec(provider: DummyProvider)

      assert spec.id == A2UI.Server
      assert spec.type == :supervisor
      assert {Bandit, :start_link, [bandit_opts]} = spec.start
      assert Keyword.get(bandit_opts, :port) == 4000
      assert Keyword.get(bandit_opts, :ip) == {127, 0, 0, 1}
      assert {A2UI.Endpoint, endpoint_opts} = Keyword.get(bandit_opts, :plug)
      assert Keyword.get(endpoint_opts, :provider) == DummyProvider
    end

    test "accepts custom port and ip" do
      spec = A2UI.Server.child_spec(provider: DummyProvider, port: 8080, ip: {0, 0, 0, 0})

      {Bandit, :start_link, [bandit_opts]} = spec.start
      assert Keyword.get(bandit_opts, :port) == 8080
      assert Keyword.get(bandit_opts, :ip) == {0, 0, 0, 0}
    end

    test "passes provider_opts through" do
      spec =
        A2UI.Server.child_spec(
          provider: DummyProvider,
          provider_opts: %{key: "value"}
        )

      {Bandit, :start_link, [bandit_opts]} = spec.start
      {A2UI.Endpoint, endpoint_opts} = Keyword.get(bandit_opts, :plug)
      assert Keyword.get(endpoint_opts, :provider_opts) == %{key: "value"}
    end

    test "raises without :provider option" do
      assert_raise KeyError, fn ->
        A2UI.Server.child_spec([])
      end
    end
  end
end
