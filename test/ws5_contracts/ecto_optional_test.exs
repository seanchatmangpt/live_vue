defmodule LiveVue.WS5.EctoOptionalTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "Ecto remains an optional integration dependency" do
    assert @manifest =~ ~s({:ecto, "~> 3.0", optional: true})
  end
end
