defmodule LiveVue.WS5.SSRViteInetsTest do
  use ExUnit.Case, async: true

  test "ViteJS SSR conditionally starts inets" do
    source = File.read!("mix.exs")
    assert source =~ "LiveVue.SSR.ViteJS -> [:inets]"
  end
end
