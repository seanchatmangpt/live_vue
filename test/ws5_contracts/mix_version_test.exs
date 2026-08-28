defmodule LiveVue.WS5.MixVersionTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "Mix release version remains 1.2.3" do
    assert @manifest =~ ~s(@version "1.2.3")
  end
end
