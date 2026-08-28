defmodule LiveVue.WS5.FindComponentExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "component discovery retains findComponent export" do
    assert @index =~ ~s(export { findComponent } from "./utils.js")
  end
end
