defmodule LiveVue.WS5.UseLiveUploadExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "upload bridge retains useLiveUpload" do
    assert @index =~ "useLiveUpload"
  end
end
