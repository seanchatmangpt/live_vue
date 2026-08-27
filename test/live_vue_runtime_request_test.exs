defmodule LiveVue.RuntimeRequestTest do
  use ExUnit.Case, async: true

  alias LiveVue.{ActionExposure, RuntimeContext, RuntimeRequest}

  setup do
    {:ok, context} = RuntimeContext.new(correlation_id: "req-42", actor: :user, tenant: :acme)
    %{context: context, exposure: ActionExposure.new([:create])}
  end

  test "binds exact subject and arguments after exposure admission", %{context: context, exposure: exposure} do
    assert {:ok, request} =
             RuntimeRequest.construct(exposure, "posts@abc123", :create, %{title: "Hello"}, context)

    assert request.subject == "posts@abc123"
    assert request.arguments == %{title: "Hello"}
  end

  test "refuses empty subject", %{context: context, exposure: exposure} do
    assert {:error, :exact_subject_required} =
             RuntimeRequest.construct(exposure, "", :create, %{}, context)
  end

  test "refuses unexposed action", %{context: context, exposure: exposure} do
    assert {:error, :action_not_exposed} =
             RuntimeRequest.construct(exposure, "posts@abc123", :destroy, %{}, context)
  end
end
