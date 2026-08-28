defmodule LiveVue.WS5.UseLiveFormExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "form bridge retains useLiveForm" do
    assert @index =~ "useLiveForm"
  end
end
