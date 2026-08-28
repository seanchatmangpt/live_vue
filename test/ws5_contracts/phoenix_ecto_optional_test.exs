defmodule LiveVue.WS5.PhoenixEctoOptionalTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "Phoenix Ecto remains an optional integration dependency" do
    assert @manifest =~ ~s({:phoenix_ecto, "~> 4.0", optional: true})
  end
end
