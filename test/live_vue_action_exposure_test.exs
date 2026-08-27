defmodule LiveVue.ActionExposureTest do
  use ExUnit.Case, async: true

  alias LiveVue.ActionExposure

  test "admits only explicitly exposed operations" do
    exposure = ActionExposure.new([:create, :read])

    assert :ok = ActionExposure.admit(exposure, :create)
    assert {:error, :action_not_exposed} = ActionExposure.admit(exposure, :destroy)
  end

  test "does not manufacture callable operations" do
    exposure = ActionExposure.new(["posts.create"])

    assert :ok = ActionExposure.admit(exposure, "posts.create")
    refute Map.has_key?(Map.from_struct(exposure), :invoke)
  end
end
