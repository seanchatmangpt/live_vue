defmodule LiveVue.ServerOperationTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias LiveVue.ServerOperation
  alias LiveVue.ServerOperation.Plug, as: ServerOperationPlug
  alias Plug.Conn

  defmodule Executor do
    @behaviour LiveVue.ServerOperation.Executor

    @impl true
    def run(operation, input, context) do
      if test_pid = context[:test_pid], do: send(test_pid, {:executed, operation, input, context})
      {:ok, %{operation: operation.id, input: input}}
    end
  end

  defmodule FailingExecutor do
    @behaviour LiveVue.ServerOperation.Executor

    @impl true
    def run(_operation, _input, _context), do: {:error, :consumer_refused}
  end

  test "validates Phoenix and Ash backend identity without adding an Ash dependency" do
    assert {:ok, phoenix} =
             ServerOperation.new("profile.refresh", "Profile@v2",
               backend: :phoenix,
               handler: "ProfileController.refresh"
             )

    assert ServerOperation.backend_identity(phoenix) == {:phoenix, "ProfileController.refresh"}

    assert {:ok, ash} =
             ServerOperation.new("posts.create", "Post@v1",
               backend: :ash,
               domain: "Blog",
               resource: "Post",
               action: "create",
               consequential: true
             )

    assert ServerOperation.backend_identity(ash) == {:ash, "Blog", "Post", "create"}
    assert ash.consequential

    assert {:error, :ash_action_required} =
             ServerOperation.new("posts.create", "Post@v1",
               backend: :ash,
               domain: "Blog",
               resource: "Post"
             )
  end

  test "refuses an unexposed operation before the executor is invoked" do
    operation =
      ServerOperation.new!("posts.create", "Post@v1",
        backend: :ash,
        domain: "Blog",
        resource: "Post",
        action: "create"
      )

    assert {:error, :operation_not_exposed} =
             ServerOperation.dispatch([operation], Executor, "posts.destroy", %{}, %{test_pid: self()})

    refute_receive {:executed, _, _, _}
  end

  test "dispatches the exact admitted operation and manufactures deterministic outcome receipts" do
    operation =
      ServerOperation.new!("posts.create", "Post@v1",
        backend: :ash,
        domain: "Blog",
        resource: "Post",
        action: "create",
        consequential: true
      )

    context = %{correlation_id: "req-1", test_pid: self()}
    input = %{"title" => "Hello"}

    assert {:ok, %{operation: "posts.create", input: ^input}, first_receipt} =
             ServerOperation.dispatch([operation], Executor, "posts.create", input, context)

    assert_receive {:executed, ^operation, ^input, ^context}

    assert {:ok, _, second_receipt} =
             ServerOperation.dispatch(%{"posts.create" => operation}, Executor, "posts.create", input, context)

    assert_receive {:executed, ^operation, ^input, ^context}
    assert first_receipt == second_receipt
    assert first_receipt.status == :ok
    assert first_receipt.executed
    assert first_receipt.correlation_id == "req-1"
    assert byte_size(first_receipt.digest) == 64
  end

  test "executor refusals receive an error outcome receipt" do
    operation =
      ServerOperation.new!("profile.refresh", "Profile@v2",
        backend: :phoenix,
        handler: "ProfileController.refresh"
      )

    assert {:error, :consumer_refused, receipt} =
             ServerOperation.dispatch([operation], FailingExecutor, "profile.refresh", %{}, %{})

    assert receipt.status == :error
    assert receipt.executed
    assert receipt.operation_id == "profile.refresh"
  end

  test "HTTP projection preserves operation identity, correlation and JSON-safe receipt evidence" do
    operation =
      ServerOperation.new!("posts.create", "Post@v1",
        backend: :ash,
        domain: "Blog",
        resource: "Post",
        action: "create"
      )

    opts =
      ServerOperationPlug.init(
        operations: [operation],
        executor: Executor,
        context: fn _conn -> %{test_pid: self()} end
      )

    conn =
      :post
      |> conn("/posts.create")
      |> Conn.put_req_header("x-correlation-id", "header-correlation")
      |> Map.put(:body_params, %{
        "input" => %{"title" => "Hello"},
        "correlation_id" => "body-correlation"
      })
      |> ServerOperationPlug.call(opts)

    assert conn.status == 200
    payload = Jason.decode!(conn.resp_body)

    assert payload["data"] == %{
             "operation" => "posts.create",
             "input" => %{"title" => "Hello"}
           }

    assert payload["receipt"]["operation_id"] == "posts.create"
    assert payload["receipt"]["subject"] == "Post@v1"
    assert payload["receipt"]["correlation_id"] == "body-correlation"
    assert payload["receipt"]["backend_identity"] == ["ash", "Blog", "Post", "create"]
    assert payload["receipt"]["status"] == "ok"
    assert payload["receipt"]["executed"] == true
  end

  test "HTTP projection refuses unknown operation IDs without executor actuation" do
    operation =
      ServerOperation.new!("posts.create", "Post@v1",
        backend: :ash,
        domain: "Blog",
        resource: "Post",
        action: "create"
      )

    opts =
      ServerOperationPlug.init(
        operations: [operation],
        executor: Executor,
        context: fn _conn -> %{test_pid: self()} end
      )

    conn =
      :post
      |> conn("/posts.destroy")
      |> Map.put(:body_params, %{"input" => %{}})
      |> ServerOperationPlug.call(opts)

    assert conn.status == 404
    assert Jason.decode!(conn.resp_body) == %{"error" => "operation_not_exposed"}
    refute_receive {:executed, _, _, _}
  end
end
