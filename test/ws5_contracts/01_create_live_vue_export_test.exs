defmodule LiveVue.WS5.CreateLiveVueExportTest do
  use ExUnit.Case, async: true

  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()

  test "consumer entrypoint keeps createLiveVue exported" do
    assert @index =~ ~s(export { createLiveVue } from "./app.js")
  end
end
