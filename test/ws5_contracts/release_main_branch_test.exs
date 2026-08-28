defmodule LiveVue.WS5.ReleaseMainBranchTest do
  use ExUnit.Case, async: true

  test "release aliases publish only from main" do
    source = File.read!("mix.exs")
    assert source =~ ~s("release.patch": ["easy_publish.release patch --branch=main"])
    assert source =~ ~s("release.minor": ["easy_publish.release minor --branch=main"])
    assert source =~ ~s("release.major": ["easy_publish.release major --branch=main"])
  end
end
