defmodule LiveVue.WS5.UseLiveConnectionExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "connection state bridge retains useLiveConnection" do
    assert @index =~ "useLiveConnection"
  end
end
