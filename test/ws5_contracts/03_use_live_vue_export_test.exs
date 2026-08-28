defmodule LiveVue.WS5.UseLiveVueExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "Vue consumers retain useLiveVue" do
    assert @index =~ "useLiveVue"
  end
end
