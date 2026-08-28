defmodule LiveVue.WS5.EctoOptionalFormsDependencyTest do
  use ExUnit.Case, async: true

  test "Ecto remains optional for form consumers" do
    source = File.read!("mix.exs")
    assert source =~ ~s({:ecto, "~> 3.0", optional: true})
  end
end
