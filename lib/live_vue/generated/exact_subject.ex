defmodule Ggen.RuntimeIntegration.ExactSubject do
  @moduledoc false
  @repo "seanchatmangpt/live_vue"
  @base "main"
  @head "ff9e17f58abab2fa39365c649535283a8d536f54"

  def identity, do: %{repo: @repo, base: @base, head: @head}
  def exact?(%{repo: @repo, base: @base, head: @head}), do: true
  def exact?(_), do: false
end
