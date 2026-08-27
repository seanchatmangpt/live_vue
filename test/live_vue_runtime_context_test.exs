defmodule LiveVue.RuntimeContextTest do
  use ExUnit.Case, async: true

  alias LiveVue.RuntimeContext

  test "requires correlation identity" do
    assert {:error, :correlation_id_required} = RuntimeContext.new([])
  end

  test "refuses missing required actor and tenant" do
    assert {:error, :actor_required} =
             RuntimeContext.new(correlation_id: "req-1", actor_required: true)

    assert {:error, :tenant_required} =
             RuntimeContext.new(correlation_id: "req-1", actor: :user, tenant_required: true)
  end

  test "constructs explicit context without granting authority" do
    assert {:ok, context} =
             RuntimeContext.new(
               correlation_id: "req-1",
               actor: :user,
               tenant: :acme,
               actor_required: true,
               tenant_required: true
             )

    assert context.actor == :user
    assert context.tenant == :acme
    refute Map.has_key?(Map.from_struct(context), :authority)
  end
end
