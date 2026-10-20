defmodule Gcf.Admin.ImageGroups do
  @moduledoc "Reusable image collections and typed, ordered links to authored content."
  alias Gcf.Database, as: DB

  @links %{
    "events" => {"event_media_groups", "event_id"},
    "initiatives" => {"initiative_media_groups", "initiative_id"},
    "campaigns" => {"campaign_media_groups", "campaign_id"},
    "articles" => {"publication_media_groups", "publication_id"},
    "newsletters" => {"publication_media_groups", "publication_id"}
  }

  def run("list", p) do
    page =
      case Integer.parse(to_string(p["page"] || 1)) do
        {n, ""} when n > 0 -> min(n, 100_000)
        _ -> 1
      end

    Gcf.Admin.Page.fetch(
      "SELECT g.*,(SELECT count(*) FROM media_group_members m WHERE m.group_id=g.id) AS photo_count,(SELECT media_id FROM media_group_members m WHERE m.group_id=g.id ORDER BY position LIMIT 1) AS cover_id FROM media_groups g WHERE title LIKE ?",
      ["%" <> String.slice(to_string(p["query"] || ""), 0, 200) <> "%"],
      "updated_at DESC,id",
      page,
      24
    )
  end

  def run("get", %{"id" => id}), do: get(id)

  def run("save", %{"data" => data} = p) do
    ids = data["media_ids"] || []
    title = data["title"]

    with true <- is_binary(title) and String.length(String.trim(title)) in 1..200,
         :ok <- check_ids("media", ids, 2000),
         {:ok, id} <-
           if(p["new_id"],
             do: {:ok, p["new_id"]},
             else: if(p["id"], do: existing(p["id"]), else: {:ok, Gcf.Admin.Content.uuid()})
           ) do
      Gcf.Admin.Mutation.target("media_groups", id, title)
      now = DateTime.to_iso8601(DateTime.utc_now())

      statements =
        [
          {"INSERT INTO media_groups(id,title,created_at,updated_at) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,updated_at=excluded.updated_at",
           [id, String.trim(title), now, now]},
          {"DELETE FROM media_group_members WHERE group_id=?", [id]}
        ] ++
          Enum.with_index(ids, fn media_id, position ->
            {"INSERT INTO media_group_members(group_id,media_id,position) VALUES(?,?,?)",
             [id, media_id, position]}
          end)

      with {:ok, _} <- DB.batch(statements), do: get(id)
    else
      false -> {:error, "A collection name is required (up to 200 characters)"}
      error -> error
    end
  end

  def run("delete", %{"id" => id}) do
    with {:ok, _} <- get(id),
         {:ok, [%{"uses" => 0}]} <-
           DB.execute("SELECT " <> uses_sql() <> " AS uses", List.duplicate(id, 4)),
         {:ok, _} <- DB.execute("DELETE FROM media_groups WHERE id=?", [id]) do
      {:ok, %{deleted: true}}
    else
      {:ok, _} -> {:error, "Remove the collection links before deleting it"}
      error -> error
    end
  end

  def run(_, _), do: {:error, "Invalid collection request"}

  def get(id) do
    with {:ok, [row]} <- DB.execute("SELECT * FROM media_groups WHERE id=?", [id]),
         {:ok, members} <-
           DB.execute(
             "SELECT media_id FROM media_group_members WHERE group_id=? ORDER BY position",
             [id]
           ),
         {:ok, [%{"uses" => uses}]} <-
           DB.execute("SELECT " <> uses_sql() <> " AS uses", List.duplicate(id, 4)) do
      {:ok,
       Map.merge(row, %{
         "media_ids" => Enum.map(members, & &1["media_id"]),
         "photo_count" => length(members),
         "uses" => uses
       })}
    else
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  def validate(nil), do: :ok
  def validate(ids), do: check_ids("media_groups", ids, 100)

  def statements(kind, id, ids) do
    case {@links[kind], ids} do
      {_, nil} ->
        []

      {{table, key}, ids} ->
        [{"DELETE FROM #{table} WHERE #{key}=?", [id]}] ++
          Enum.with_index(ids, fn group_id, position ->
            {"INSERT INTO #{table}(#{key},group_id,position) VALUES(?,?,?)",
             [id, group_id, position]}
          end)

      _ ->
        []
    end
  end

  def attach({:ok, %{items: rows} = result}, kind) when is_map_key(@links, kind),
    do: {:ok, %{result | items: attach_rows(rows, kind)}}

  def attach({:ok, %{"id" => _} = row}, kind) when is_map_key(@links, kind),
    do: {:ok, hd(attach_rows([row], kind))}

  def attach(result, _), do: result

  defp attach_rows([], _), do: []

  defp attach_rows(rows, kind) do
    {table, key} = @links[kind]
    ids = Enum.map(rows, & &1["id"])

    {:ok, links} =
      DB.execute(
        "SELECT #{key} AS owner,group_id FROM #{table} WHERE #{key} IN (#{slots(ids)}) ORDER BY position",
        ids
      )

    Enum.map(rows, fn row ->
      Map.put(
        row,
        "group_ids",
        for(link <- links, link["owner"] == row["id"], do: link["group_id"])
      )
    end)
  end

  defp existing(id), do: with({:ok, _} <- get(id), do: {:ok, id})

  defp check_ids(table, ids, maximum) do
    if is_list(ids) and length(ids) <= maximum and length(Enum.uniq(ids)) == length(ids) and
         Enum.all?(ids, &(is_binary(&1) and Regex.match?(~r/^[a-f0-9]{32}$/, &1))) do
      if ids == [] do
        :ok
      else
        case DB.execute("SELECT id FROM #{table} WHERE id IN (#{slots(ids)})", ids) do
          {:ok, rows} when length(rows) == length(ids) -> :ok
          _ -> {:error, "A selected image or collection no longer exists"}
        end
      end
    else
      {:error, "Choose unique images or collections within the selection limit"}
    end
  end

  defp slots(ids), do: Enum.map_join(ids, ",", fn _ -> "?" end)

  defp uses_sql,
    do:
      Enum.map_join(
        ~w(event_media_groups initiative_media_groups campaign_media_groups publication_media_groups),
        "+",
        &"(SELECT count(*) FROM #{&1} WHERE group_id=?)"
      )
end
