defmodule LiveVue.WS5.E2EIgnoreContractTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "default test paths keep E2E fixtures isolated" do
    assert @manifest =~ ~s(test_ignore_filters: [~r"/e2e/"])
  end
end
