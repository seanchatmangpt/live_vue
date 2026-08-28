defmodule Ggen.RuntimeIntegration.RuntimeConfig do
  @moduledoc false
  @digest "live-vue-public-runtime-config-v1"
  @config "live_vue.public_runtime_config"

  def admitted, do: %{digest: @digest, config: @config}
  def matches?(digest), do: digest == @digest
end
