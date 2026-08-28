defmodule LiveVue.WS5.IgniterOptionalDependencyTest do
  use ExUnit.Case, async: true

  test "Igniter remains an optional installer seam" do
    source = File.read!("mix.exs")
    assert source =~ ~s({:igniter, "~> 0.6", optional: true})
  end
end
