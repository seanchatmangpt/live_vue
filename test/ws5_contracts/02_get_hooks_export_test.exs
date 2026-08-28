defmodule LiveVue.WS5.GetHooksExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "Phoenix integration keeps getHooks exported" do
    assert @index =~ ~s(export { getHooks } from "./hooks.js")
  end
end
