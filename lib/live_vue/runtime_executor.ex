defmodule LiveVue.RuntimeExecutor do
  @moduledoc """
  Behaviour for optional server runtimes such as Ash.

  LiveVue constructs an admitted `LiveVue.RuntimeRequest`; a consumer-owned
  executor decides how that request maps to its runtime. Implementing this
  behaviour does not make an executor trusted or authorized automatically.
  """

  alias LiveVue.RuntimeRequest

  @callback run(RuntimeRequest.t()) :: {:ok, term()} | {:error, term()}
end
