defmodule LiveVue.WS5.TelemetryContractTest do
  use ExUnit.Case, async: true
  @manifest File.read!("mix.exs")

  test "telemetry remains compatible with both legacy and 1.x consumers" do
    assert @manifest =~ ~s({:telemetry, "~> 0.4 or ~> 1.0"})
  end
end
