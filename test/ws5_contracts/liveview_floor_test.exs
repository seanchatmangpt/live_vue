defmodule LiveVue.WS5.LiveViewFloorTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "Phoenix LiveView dependency floor remains >= 0.18.0" do
    assert @manifest =~ ~s({:phoenix_live_view, ">= 0.18.0"})
  end
end
