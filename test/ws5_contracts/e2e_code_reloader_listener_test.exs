defmodule LiveVue.WS5.E2ECodeReloaderListenerTest do
  use ExUnit.Case, async: true

  test "e2e listener enables Phoenix code reloader" do
    source = File.read!("mix.exs")
    assert source =~ "defp listeners(:e2e), do: [Phoenix.CodeReloader]"
  end
end
