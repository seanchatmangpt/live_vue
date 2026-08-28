defmodule LiveVue.WS5.UseLiveEventExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "event bridge retains useLiveEvent" do
    assert @index =~ "useLiveEvent"
  end
end
