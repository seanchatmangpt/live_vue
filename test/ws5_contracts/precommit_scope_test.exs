defmodule LiveVue.WS5.PrecommitScopeTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "precommit keeps unit, format, E2E, and asset gates" do
    assert @manifest =~ ~s(precommit: ["test", "format", "e2e.test", "assets.test"])
  end
end
