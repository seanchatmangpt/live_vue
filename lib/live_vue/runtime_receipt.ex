defmodule LiveVue.RuntimeReceipt do
  @moduledoc """
  Deterministic receipt for a runtime request construction boundary.

  This receipt records construction only. `actuation_performed` is permanently
  false and the receipt never grants permission to execute a server action.
  """

  alias LiveVue.RuntimeRequest

  @enforce_keys [:digest, :subject, :action, :correlation_id]
  defstruct [:digest, :subject, :action, :correlation_id, phase: :construct, actuation_performed: false]

  @type t :: %__MODULE__{
          digest: String.t(),
          subject: String.t(),
          action: atom() | String.t(),
          correlation_id: String.t(),
          phase: :construct,
          actuation_performed: false
        }

  @spec issue(RuntimeRequest.t()) :: t()
  def issue(%RuntimeRequest{} = request) do
    body = {
      request.subject,
      request.action,
      request.arguments,
      request.context.actor,
      request.context.tenant,
      request.context.correlation_id,
      request.context.causation_id
    }

    digest =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary(body, [:deterministic]))
      |> Base.encode16(case: :lower)

    %__MODULE__{
      digest: digest,
      subject: request.subject,
      action: request.action,
      correlation_id: request.context.correlation_id
    }
  end

  @spec replay?(RuntimeRequest.t(), t()) :: boolean()
  def replay?(%RuntimeRequest{} = request, %__MODULE__{} = receipt) do
    issued = issue(request)

    receipt.actuation_performed == false and
      receipt.phase == :construct and
      issued.digest == receipt.digest and
      issued.subject == receipt.subject and
      issued.action == receipt.action and
      issued.correlation_id == receipt.correlation_id
  end
end
