defmodule Gcf.IdentityTest do
  use ExUnit.Case, async: true
  alias Gcf.Admin.{Auth, Mutation}

  test "runtime writes require an explicit Ash mutation context" do
    assert {:error, :audit_context_required} = Gcf.Database.execute("DELETE FROM events")
  end

  test "the authenticated actor wins over request data and context cannot leak" do
    actor = %{"id" => "trusted-account"}
    params = %{"actor_id" => "forged", "collection" => "events", "data" => %{"title" => "Event"}}

    Mutation.run(actor, "save", params, fn ->
      assert {:ok, [{_, [_id, "trusted-account", "create", "events", nil, "Event", _time]} | _],
              2, 1} = Mutation.frame([{"INSERT INTO events VALUES (?)", ["id"]}], [])
    end)

    assert {:error, :audit_context_required} = Mutation.frame([{"DELETE FROM events", []}], [])

    assert_raise RuntimeError, fn ->
      Mutation.run(actor, "delete", %{}, fn -> raise "interrupted" end)
    end

    assert {:error, :audit_context_required} = Mutation.frame([{"DELETE FROM events", []}], [])
  end

  test "editors receive a typed forbidden error for account management" do
    result =
      Gcf.Admin.Resource
      |> Ash.ActionInput.for_action(:run, %{operation: "list_users", params: %{}},
        actor: %{"id" => "editor", "role" => "editor"}
      )
      |> Ash.run_action()

    assert {:error, %Ash.Error.Forbidden{}} = result
  end

  test "stored hashes verify only the matching password" do
    password = "a sufficiently long password"
    hash = Auth.hash_password(password)
    refute String.contains?(hash, password)
    assert Auth.verify_hash(password, hash)
    refute Auth.verify_hash("wrong password", hash)
    refute Auth.verify_hash(nil, hash)
  end
end
