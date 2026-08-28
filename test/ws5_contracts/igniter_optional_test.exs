defmodule LiveVue.WS5.IgniterOptionalTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "Igniter remains an optional consumer seam" do
    assert @manifest =~ ~s({:igniter, "~> 0.6", optional: true})
  end
end
