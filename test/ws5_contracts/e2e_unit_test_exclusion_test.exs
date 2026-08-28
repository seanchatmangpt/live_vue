defmodule LiveVue.WS5.E2EUnitTestExclusionTest do
  use ExUnit.Case, async: true

  test "unit suite excludes e2e fixtures" do
    source = File.read!("mix.exs")
    assert source =~ ~s(test_ignore_filters: [~r"/e2e/"])
  end
end
