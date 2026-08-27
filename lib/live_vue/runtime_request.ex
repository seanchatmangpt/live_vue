defmodule LiveVue.RuntimeRequest do
  @moduledoc """
  Immutable SELECT/CONSTRUCT request for an explicitly exposed server action.

  The request binds an exact server subject, action, arguments, and runtime
  context. It is not an execution token.
  """

  alias LiveVue.{ActionExposure, RuntimeContext}

  @enforce_keys [:subject, :action, :arguments, :context]
  defstruct [:subject, :action, :arguments, :context]

  @type t :: %__MODULE__{
          subject: String.t(),
          action: ActionExposure.action(),
          arguments: map(),
          context: RuntimeContext.t()
        }

  @spec construct(ActionExposure.t(), String.t(), ActionExposure.action(), map(), RuntimeContext.t()) ::
          {:ok, t()} | {:error, atom()}
  def construct(exposure, subject, action, arguments, %RuntimeContext{} = context)
      when is_map(arguments) do
    with :ok <- exact_subject(subject),
         :ok <- ActionExposure.admit(exposure, action) do
      {:ok,
       %__MODULE__{
         subject: subject,
         action: action,
         arguments: arguments,
         context: context
       }}
    end
  end

  defp exact_subject(subject) when is_binary(subject) and byte_size(subject) > 0, do: :ok
  defp exact_subject(_), do: {:error, :exact_subject_required}
end
