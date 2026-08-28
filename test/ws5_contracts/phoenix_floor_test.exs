defmodule LiveVue.WS5.PhoenixFloorTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "Phoenix dependency floor remains >= 1.7.0" do
    assert @manifest =~ ~s({:phoenix, ">= 1.7.0"})
  end
end
