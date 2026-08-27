defmodule LiveVue.ActionExposure do
  @moduledoc """
  Explicit allow-list for server operations that may be projected to a Vue client.

  Exposure is admission only. It does not invoke the operation and confers no
  runtime authority.
  """

  @enforce_keys [:actions]
  defstruct [:actions]

  @type action :: atom() | String.t()
  @type t :: %__MODULE__{actions: MapSet.t(action())}

  @spec new(Enumerable.t()) :: t()
  def new(actions), do: %__MODULE__{actions: MapSet.new(actions)}

  @spec admit(t(), action()) :: :ok | {:error, :action_not_exposed}
  def admit(%__MODULE__{actions: actions}, action) do
    if MapSet.member?(actions, action), do: :ok, else: {:error, :action_not_exposed}
  end
end
