defmodule LiveVue.WS5.ElixirFloorTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "Elixir compatibility floor remains ~> 1.15" do
    assert @manifest =~ ~s(elixir: "~> 1.15")
  end
end
