defmodule LiveVue.Ash do
  @moduledoc """
  Optional runtime seam for Ash-backed LiveVue applications.

  The adapter is dependency-neutral: LiveVue owns request admission and receipt
  identity, while the application supplies an executor implementing
  `LiveVue.RuntimeExecutor`. This keeps Ash optional for existing LiveVue users.
  """

  alias LiveVue.{ActionExposure, RuntimeContext, RuntimeReceipt, RuntimeRequest}

  @ggen_pack "ash-runtime-integration-contract-pack"

  @spec ggen_pack() :: String.t()
  def ggen_pack, do: @ggen_pack

  @spec call(module(), ActionExposure.t(), String.t(), ActionExposure.action(), map(), RuntimeContext.t()) ::
          {:ok, term(), RuntimeReceipt.t()} | {:error, term()}
  def call(executor, exposure, subject, action, arguments, %RuntimeContext{} = context)
      when is_atom(executor) and is_map(arguments) do
    with {:ok, request} <- RuntimeRequest.construct(exposure, subject, action, arguments, context),
         {:ok, result} <- executor.run(request) do
      {:ok, result, RuntimeReceipt.issue(request)}
    end
  end
end
