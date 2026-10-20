defmodule Gcf.RealtimeTest do
  use ExUnit.Case, async: true
  alias Gcf.Admin.Mutation

  test "socket handshake rejects missing and invalid tickets" do
    socket = %Phoenix.Socket{}
    assert :error = GcfWeb.UserSocket.connect(%{}, socket, %{})
    assert :error = GcfWeb.UserSocket.connect(%{"token" => "forged"}, socket, %{})
  end

  test "stale-save precondition precedes the audited write in the same transaction" do
    params = %{"collection" => "events", "id" => "e", "data" => %{"updated_at" => "old"}}

    Mutation.run(%{"id" => "u"}, "save", params, fn ->
      assert {:ok, [_action, {check, ["e", "old", _action_id]} | _], 2, 1} =
               Mutation.frame([{"UPDATE events SET title=? WHERE id=?", ["New", "e"]}], [])

      assert check =~ "updated_at=?"
      assert check =~ "CASE WHEN EXISTS"
    end)
  end

  test "presence and read operations do not create mutation notifications" do
    Phoenix.PubSub.subscribe(Gcf.PubSub, "admin:changes")

    Mutation.run(%{"id" => "u"}, "media_list", %{}, fn ->
      assert {:ok, _, 0, 0} = Mutation.frame([{"SELECT 1", []}], [])
    end)

    refute_receive {:changed, _}, 20
  end
end
