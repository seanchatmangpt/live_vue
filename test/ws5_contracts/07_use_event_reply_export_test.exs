defmodule LiveVue.WS5.UseEventReplyExportTest do
  use ExUnit.Case, async: true
  @index Path.expand("../../assets/index.ts", __DIR__) |> File.read!()
  test "request reply bridge retains useEventReply" do
    assert @index =~ "useEventReply"
  end
end
