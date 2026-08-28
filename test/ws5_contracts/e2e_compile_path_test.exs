defmodule LiveVue.WS5.E2ECompilePathTest do
  use ExUnit.Case, async: true

  test "e2e environment compiles colocated feature modules" do
    source = File.read!("mix.exs")
    assert source =~ ~s|defp elixirc_paths(:e2e), do: ["lib", "test/e2e/features"]|
  end
end
