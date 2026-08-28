defmodule LiveVue.WS5.NodejsOptionalTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "NodeJS remains an optional runtime seam" do
    assert @manifest =~ ~s({:nodejs, "~> 3.1", optional: true})
  end
end
