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
      assert {:ok, [{create, []}, {check, ["e", "old"]}, {drop, []} | _], 5, 1} =
               Mutation.frame([{"UPDATE events SET title=? WHERE id=?", ["New", "e"]}], [])

      assert create =~ "CREATE TEMP TABLE"
      assert check =~ "updated_at=?"
      assert drop =~ "DROP TABLE"
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
