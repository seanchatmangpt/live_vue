defmodule LiveVue.AshTest do
  use ExUnit.Case, async: true

  alias LiveVue.{ActionExposure, RuntimeContext}

  defmodule Executor do
    @behaviour LiveVue.RuntimeExecutor

    @impl true
    def run(request), do: {:ok, %{action: request.action, args: request.arguments}}
  end

  test "executes only after explicit exposure and returns construction receipt" do
    {:ok, context} =
      RuntimeContext.new(
        correlation_id: "req-ash-1",
        actor: :user,
        tenant: :acme,
        actor_required: true,
        tenant_required: true
      )

    exposure = ActionExposure.new([:create])

    assert {:ok, %{action: :create, args: %{title: "Hello"}}, receipt} =
             LiveVue.Ash.call(Executor, exposure, "Post@v1", :create, %{title: "Hello"}, context)

    assert receipt.phase == :construct
    assert receipt.actuation_performed == false
    assert LiveVue.Ash.ggen_pack() == "ash-runtime-integration-contract-pack"
  end

  test "refuses unexposed runtime action before executor call" do
    {:ok, context} = RuntimeContext.new(correlation_id: "req-ash-2")
    exposure = ActionExposure.new([:read])

    assert {:error, :action_not_exposed} =
             LiveVue.Ash.call(Executor, exposure, "Post@v1", :destroy, %{}, context)
  end
end
