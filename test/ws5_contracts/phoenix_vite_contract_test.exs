defmodule LiveVue.WS5.PhoenixViteContractTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "Phoenix Vite integration remains ~> 0.5" do
    assert @manifest =~ ~s({:phoenix_vite, "~> 0.5"})
  end
end
