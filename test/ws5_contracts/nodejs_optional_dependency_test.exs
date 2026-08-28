defmodule LiveVue.WS5.NodeJSOptionalDependencyTest do
  use ExUnit.Case, async: true

  test "NodeJS SSR remains optional for consumers" do
    source = File.read!("mix.exs")
    assert source =~ ~s({:nodejs, "~> 3.1", optional: true})
  end
end
