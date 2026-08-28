defmodule LiveVue.WS5.PackageTestExclusionTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "package excludes JavaScript and TypeScript test artifacts" do
    assert @manifest =~ ~s(exclude_patterns: [~r/\\.test\\.[jt]s$/)
    assert @manifest =~ ~s(~r/assets\\/tests\\//)
  end
end
