defmodule LiveVue.WS5.UseLiveNavigationExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "navigation bridge retains useLiveNavigation" do
    assert @index =~ "useLiveNavigation"
  end
end
