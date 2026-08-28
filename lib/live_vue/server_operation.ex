defmodule LiveVue.ServerOperation do
  @moduledoc """
  Typed, explicitly exposed server-operation contract for LiveVue consumers.

  LiveVue owns operation identity, admission and receipt manufacture. Applications
  own execution through a module implementing `LiveVue.ServerOperation.Executor`.
  Ash remains optional: an Ash-backed operation records domain/resource/action
  identity, while the consumer executor decides how that identity maps to Ash.

  Operation metadata never grants ambient execution authority. An operation must
  be present in the registry supplied to `dispatch/5` before an executor is called.
  Operations may additionally require server-derived actor and tenant identities;
  those admission checks happen before the executor boundary.
  """

  alias __MODULE__.Receipt

  @enforce_keys [:id, :subject, :backend]
  defstruct [
    :id,
    :subject,
    :backend,
    :handler,
    :domain,
    :resource,
    :action,
    consequential: false,
    requires_actor: false,
    requires_tenant: false
  ]

  @type backend :: :phoenix | :ash
  @type t :: %__MODULE__{
          id: String.t(),
          subject: String.t(),
          backend: backend(),
          handler: String.t() | nil,
          domain: String.t() | nil,
          resource: String.t() | nil,
          action: String.t() | nil,
          consequential: boolean(),
          requires_actor: boolean(),
          requires_tenant: boolean()
        }

  @spec new(String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def new(id, subject, opts) when is_binary(id) and is_binary(subject) and is_list(opts) do
    backend = opts[:backend]

    with :ok <- nonempty(id, :operation_id_required),
         :ok <- nonempty(subject, :operation_subject_required),
         :ok <- validate_backend(backend, opts),
         :ok <- validate_boolean_option(opts[:consequential], :invalid_consequential_flag),
         :ok <- validate_boolean_option(opts[:requires_actor], :invalid_actor_requirement),
         :ok <- validate_boolean_option(opts[:requires_tenant], :invalid_tenant_requirement) do
      {:ok,
       %__MODULE__{
         id: id,
         subject: subject,
         backend: backend,
         handler: opts[:handler],
         domain: opts[:domain],
         resource: opts[:resource],
         action: opts[:action],
         consequential: opts[:consequential] == true,
         requires_actor: opts[:requires_actor] == true,
         requires_tenant: opts[:requires_tenant] == true
       }}
    end
  end

  def new(_, _, _), do: {:error, :invalid_operation_descriptor}

  @spec new!(String.t(), String.t(), keyword()) :: t()
  def new!(id, subject, opts) do
    case new(id, subject, opts) do
      {:ok, operation} -> operation
      {:error, reason} -> raise ArgumentError, "invalid LiveVue server operation: #{inspect(reason)}"
    end
  end

  @doc "Returns the stable backend identity bound into receipts and replay evidence."
  @spec backend_identity(t()) :: tuple()
  def backend_identity(%__MODULE__{backend: :phoenix, handler: handler}), do: {:phoenix, handler}

  def backend_identity(%__MODULE__{backend: :ash, domain: domain, resource: resource, action: action}),
    do: {:ash, domain, resource, action}

  @doc """
  Dispatches an exposed operation through a consumer-owned executor.

  The operation registry is the exposure boundary. Unknown operation IDs and
  missing required actor/tenant identities are refused before the executor is
  invoked. Every executor attempt manufactures an outcome receipt, including
  typed executor errors.
  """
  @spec dispatch([t()] | %{optional(String.t()) => t()}, module(), String.t(), term(), map()) ::
          {:ok, term(), Receipt.t()}
          | {:error, term(), Receipt.t()}
          | {:error,
             :operation_not_exposed
             | :actor_required
             | :tenant_required
             | :invalid_executor}
  def dispatch(operations, executor, id, input, context \\ %{})
      when is_binary(id) and is_atom(executor) and is_map(context) do
    with {:ok, operation} <- fetch_operation(operations, id),
         :ok <- admit_context(operation, context),
         :ok <- validate_executor(executor) do
      case executor.run(operation, input, context) do
        {:ok, result} ->
          {:ok, result, Receipt.issue(operation, input, context, {:ok, result})}

        {:error, reason} ->
          {:error, reason, Receipt.issue(operation, input, context, {:error, reason})}

        other ->
          reason = {:invalid_executor_result, other}
          {:error, reason, Receipt.issue(operation, input, context, {:error, reason})}
      end
    end
  end

  def dispatch(_, _, _, _, _), do: {:error, :invalid_executor}

  defp fetch_operation(operations, id) when is_map(operations) do
    case Map.fetch(operations, id) do
      {:ok, %__MODULE__{} = operation} -> {:ok, operation}
      _ -> {:error, :operation_not_exposed}
    end
  end

  defp fetch_operation(operations, id) when is_list(operations) do
    case Enum.find(operations, &match?(%__MODULE__{id: ^id}, &1)) do
      %__MODULE__{} = operation -> {:ok, operation}
      nil -> {:error, :operation_not_exposed}
    end
  end

  defp fetch_operation(_, _), do: {:error, :operation_not_exposed}

  defp admit_context(%__MODULE__{} = operation, context) do
    with :ok <- require_identity(operation.requires_actor, context_identity(context, :actor), :actor_required),
         :ok <-
           require_identity(operation.requires_tenant, context_identity(context, :tenant), :tenant_required) do
      :ok
    end
  end

  defp require_identity(true, nil, reason), do: {:error, reason}
  defp require_identity(_, _, _), do: :ok

  defp context_identity(context, key), do: Map.get(context, key) || Map.get(context, Atom.to_string(key))

  defp validate_executor(executor) do
    if function_exported?(executor, :run, 3), do: :ok, else: {:error, :invalid_executor}
  end

  defp validate_backend(:phoenix, opts), do: nonempty(opts[:handler], :phoenix_handler_required)

  defp validate_backend(:ash, opts) do
    with :ok <- nonempty(opts[:domain], :ash_domain_required),
         :ok <- nonempty(opts[:resource], :ash_resource_required),
         :ok <- nonempty(opts[:action], :ash_action_required) do
      :ok
    end
  end

  defp validate_backend(_, _), do: {:error, :unsupported_backend}

  defp validate_boolean_option(nil, _reason), do: :ok
  defp validate_boolean_option(value, _reason) when is_boolean(value), do: :ok
  defp validate_boolean_option(_value, reason), do: {:error, reason}

  defp nonempty(value, _) when is_binary(value) and byte_size(value) > 0, do: :ok
  defp nonempty(_, reason), do: {:error, reason}
end

defmodule LiveVue.ServerOperation.Executor do
  @moduledoc """
  Consumer-owned execution boundary for typed LiveVue server operations.

  Implementations may call Phoenix application services, Ash actions, Reactor or
  another admitted runtime. Implementing this behaviour does not itself expose an
  operation; exposure is controlled by the registry passed to dispatch.
  """

  alias LiveVue.ServerOperation

  @callback run(ServerOperation.t(), term(), map()) :: {:ok, term()} | {:error, term()}
end

defmodule LiveVue.ServerOperation.Receipt do
  @moduledoc "Deterministic outcome receipt for one admitted server-operation executor attempt."

  alias LiveVue.ServerOperation

  @enforce_keys [:digest, :operation_id, :subject, :backend_identity, :status, :executed]
  defstruct [:digest, :operation_id, :subject, :backend_identity, :correlation_id, :status, executed: true]

  @type t :: %__MODULE__{
          digest: String.t(),
          operation_id: String.t(),
          subject: String.t(),
          backend_identity: tuple(),
          correlation_id: String.t() | nil,
          status: :ok | :error,
          executed: true
        }

  @spec issue(ServerOperation.t(), term(), map(), {:ok, term()} | {:error, term()}) :: t()
  def issue(%ServerOperation{} = operation, input, context, outcome) when is_map(context) do
    correlation_id = context_identity(context, :correlation_id)
    actor = context_identity(context, :actor)
    tenant = context_identity(context, :tenant)
    backend_identity = ServerOperation.backend_identity(operation)
    status = if match?({:ok, _}, outcome), do: :ok, else: :error

    digest =
      {operation.id, operation.subject, backend_identity, operation.consequential, input, actor, tenant,
       correlation_id, outcome}
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    %__MODULE__{
      digest: digest,
      operation_id: operation.id,
      subject: operation.subject,
      backend_identity: backend_identity,
      correlation_id: correlation_id,
      status: status
    }
  end

  @doc "JSON-safe public receipt projection used by the HTTP seam."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = receipt) do
    %{
      digest: receipt.digest,
      operation_id: receipt.operation_id,
      subject: receipt.subject,
      backend_identity: Tuple.to_list(receipt.backend_identity),
      correlation_id: receipt.correlation_id,
      status: Atom.to_string(receipt.status),
      executed: receipt.executed
    }
  end

  defp context_identity(context, key), do: Map.get(context, key) || Map.get(context, Atom.to_string(key))
end

defmodule LiveVue.ServerOperation.Plug do
  @moduledoc """
  Phoenix/Plug HTTP projection for `LiveVue.ServerOperation`.

  The plug expects JSON body params to have already been fetched by
  `Plug.Parsers`. It can be mounted under a path such as `/live_vue/operations`
  and accepts the operation ID from `path_params["id"]`, the JSON operation
  descriptor, `operation_id`, or the remaining forwarded path segment.

  Actor and tenant identities are accepted only from the server-owned context
  callback. Client body data may supply correlation identity but cannot satisfy
  actor or tenant admission requirements.
  """

  @behaviour Plug

  alias LiveVue.ServerOperation
  alias LiveVue.ServerOperation.Receipt
  alias Plug.Conn

  @impl true
  def init(opts) do
    %{
      operations: Keyword.fetch!(opts, :operations),
      executor: Keyword.fetch!(opts, :executor),
      context: Keyword.get(opts, :context, &default_context/1)
    }
  end

  @impl true
  def call(%Conn{} = conn, opts) do
    with {:ok, body} <- fetched_body_params(conn),
         {:ok, operation_id} <- operation_id(conn, body),
         {:ok, context} <- build_context(opts.context, conn, body) do
      input = Map.get(body, "input", %{})

      case ServerOperation.dispatch(opts.operations, opts.executor, operation_id, input, context) do
        {:ok, result, receipt} ->
          send_json(conn, 200, %{data: result, receipt: Receipt.to_map(receipt)})

        {:error, :operation_not_exposed} ->
          send_json(conn, 404, %{error: "operation_not_exposed"})

        {:error, reason} when reason in [:actor_required, :tenant_required] ->
          send_json(conn, 403, %{error: Atom.to_string(reason)})

        {:error, :invalid_executor} ->
          send_json(conn, 500, %{error: "invalid_executor"})

        {:error, reason, receipt} ->
          send_json(conn, 422, %{error: inspect(reason), receipt: Receipt.to_map(receipt)})
      end
    else
      {:error, reason} -> send_json(conn, 400, %{error: Atom.to_string(reason)})
    end
  end

  defp fetched_body_params(%Conn{body_params: %Plug.Conn.Unfetched{}}), do: {:error, :body_params_not_fetched}
  defp fetched_body_params(%Conn{body_params: body}) when is_map(body), do: {:ok, body}
  defp fetched_body_params(_), do: {:error, :invalid_body_params}

  defp operation_id(conn, body) do
    nested =
      case Map.get(body, "operation") do
        %{} = operation -> Map.get(operation, "id")
        _ -> nil
      end

    id = path_param_id(conn) || nested || Map.get(body, "operation_id") || List.last(conn.path_info)

    if is_binary(id) and byte_size(id) > 0,
      do: {:ok, id},
      else: {:error, :operation_id_required}
  end

  defp path_param_id(%Conn{path_params: %Plug.Conn.Unfetched{}}), do: nil
  defp path_param_id(%Conn{path_params: path_params}) when is_map(path_params), do: Map.get(path_params, "id")
  defp path_param_id(_), do: nil

  defp build_context(context_fun, conn, body) when is_function(context_fun, 1) do
    case context_fun.(conn) do
      %{} = context ->
        context =
          case Map.get(body, "correlation_id") do
            value when is_binary(value) and byte_size(value) > 0 -> Map.put(context, :correlation_id, value)
            _ -> context
          end

        {:ok, context}

      _ ->
        {:error, :invalid_operation_context}
    end
  end

  defp build_context(_, _, _), do: {:error, :invalid_operation_context}

  defp default_context(conn) do
    case Conn.get_req_header(conn, "x-correlation-id") do
      [correlation_id | _] -> %{correlation_id: correlation_id}
      [] -> %{}
    end
  end

  defp send_json(conn, status, body) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(status, Jason.encode!(body))
  end
end
