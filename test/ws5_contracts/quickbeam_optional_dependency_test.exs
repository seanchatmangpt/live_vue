defmodule LiveVue.WS5.QuickBEAMOptionalDependencyTest do
  use ExUnit.Case, async: true

  test "QuickBEAM production SSR remains optional" do
    source = File.read!("mix.exs")
    assert source =~ ~s({:quickbeam, "~> 0.8", optional: true})
  end
end
