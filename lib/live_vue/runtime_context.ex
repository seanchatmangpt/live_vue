defmodule LiveVue.RuntimeContext do
  @moduledoc """
  Explicit runtime context for server operations exposed to Vue clients.

  Context is data only. It carries actor/tenant/correlation identity but grants no
  execution authority by itself.
  """

  @enforce_keys [:correlation_id]
  defstruct [:actor, :tenant, :correlation_id, :causation_id, metadata: %{}]

  @type t :: %__MODULE__{
          actor: term() | nil,
          tenant: term() | nil,
          correlation_id: String.t(),
          causation_id: String.t() | nil,
          metadata: map()
        }

  @spec new(keyword()) :: {:ok, t()} | {:error, atom()}
  def new(opts) do
    with {:ok, correlation_id} <- nonempty(opts[:correlation_id], :correlation_id_required),
         :ok <- required_identity(opts[:actor], opts[:actor_required], :actor_required),
         :ok <- required_identity(opts[:tenant], opts[:tenant_required], :tenant_required) do
      {:ok,
       %__MODULE__{
         actor: opts[:actor],
         tenant: opts[:tenant],
         correlation_id: correlation_id,
         causation_id: opts[:causation_id],
         metadata: Map.new(opts[:metadata] || %{})
       }}
    end
  end

  defp nonempty(value, _) when is_binary(value) and byte_size(value) > 0, do: {:ok, value}
  defp nonempty(_, reason), do: {:error, reason}

  defp required_identity(nil, true, reason), do: {:error, reason}
  defp required_identity(_, _, _), do: :ok
end
