defmodule LiveVue.WS5.PhoenixEctoOptionalDependencyTest do
  use ExUnit.Case, async: true

  test "Phoenix Ecto remains optional for form integration" do
    source = File.read!("mix.exs")
    assert source =~ ~s({:phoenix_ecto, "~> 4.0", optional: true})
  end
end
