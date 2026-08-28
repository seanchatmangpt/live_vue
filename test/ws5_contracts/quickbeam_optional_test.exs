defmodule LiveVue.WS5.QuickbeamOptionalTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "QuickBEAM remains an optional SSR seam" do
    assert @manifest =~ ~s({:quickbeam, "~> 0.8", optional: true})
  end
end
