defmodule LiveVue.RuntimeReceiptTest do
  use ExUnit.Case, async: true

  alias LiveVue.{ActionExposure, RuntimeContext, RuntimeReceipt, RuntimeRequest}

  defp request(title \\ "Hello") do
    {:ok, context} = RuntimeContext.new(correlation_id: "req-7", actor: :user, tenant: :acme)
    exposure = ActionExposure.new([:create])
    {:ok, request} = RuntimeRequest.construct(exposure, "posts@abc123", :create, %{title: title}, context)
    request
  end

  test "receipt is deterministic and construction-only" do
    first = RuntimeReceipt.issue(request())
    second = RuntimeReceipt.issue(request())

    assert first == second
    assert first.phase == :construct
    assert first.actuation_performed == false
    assert RuntimeReceipt.replay?(request(), first)
  end

  test "argument tamper refuses replay" do
    receipt = RuntimeReceipt.issue(request())
    refute RuntimeReceipt.replay?(request("Changed"), receipt)
  end

  test "actuation claim refuses replay" do
    receipt = %{RuntimeReceipt.issue(request()) | actuation_performed: true}
    refute RuntimeReceipt.replay?(request(), receipt)
  end
end
