defmodule Ggen.RuntimeIntegration.ApiContract do
  @moduledoc false
  @route "/live_vue/operations/:id"
  @method "POST"

  def contract, do: %{route: @route, method: @method}
end
