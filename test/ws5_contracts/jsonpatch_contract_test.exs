defmodule LiveVue.WS5.JsonpatchContractTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "jsonpatch dependency remains ~> 2.3" do
    assert @manifest =~ ~s({:jsonpatch, "~> 2.3"})
  end
end
