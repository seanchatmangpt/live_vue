defmodule Ggen.RuntimeIntegration.AuthorityGate do
  @moduledoc false
  @allowed_action "http://www.w3.org/ns/odrl/2/use"

  def authorize(%{action: @allowed_action, policy: policy}) when not is_nil(policy), do: :ok
  def authorize(%{action: action}), do: {:error, {:refused, :authority, action}}
  def authorize(_), do: {:error, {:refused, :authority, :missing_action}}
end
