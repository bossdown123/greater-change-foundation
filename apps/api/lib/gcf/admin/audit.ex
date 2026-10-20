defmodule Gcf.Admin.Audit do
  alias Gcf.Database, as: DB

  def actors do
    with {:ok, rows} <-
           DB.execute(
             "SELECT a.id,COALESCE(u.name,a.label) AS name FROM actors a LEFT JOIN users u ON u.id=a.id ORDER BY name"
           ),
         do: {:ok, %{items: rows}}
  end

  def run("audit_list", p) do
    query = "%" <> String.slice(to_string(p["query"] || ""), 0, 200) <> "%"

    filters = [
      {"a.actor_id", p["actor"]},
      {"a.resource_type", p["type"]},
      {"a.operation", p["operation"]},
      {"a.resource_id", p["resource_id"]}
    ]

    {where, args} =
      Enum.reduce(
        filters,
        {"(a.resource_title LIKE ? OR COALESCE(u.name,s.label) LIKE ? OR COALESCE(u.email,'') LIKE ?)",
         [query, query, query]},
        fn
          {_, nil}, acc -> acc
          {_, ""}, acc -> acc
          {field, value}, {sql, args} -> {sql <> " AND " <> field <> "=?", args ++ [value]}
        end
      )

    {where, args} =
      Enum.reduce(
        [{"a.occurred_at>=?", p["from"]}, {"a.occurred_at<?", end_date(p["to"])}],
        {where, args},
        fn
          {_, nil}, acc -> acc
          {_, ""}, acc -> acc
          {clause, value}, {sql, args} -> {sql <> " AND " <> clause, args ++ [value]}
        end
      )

    Gcf.Admin.Page.fetch(
      "SELECT a.*,COALESCE(u.name,s.label) AS actor_name,u.email AS actor_email FROM audit_actions a JOIN actors s ON s.id=a.actor_id LEFT JOIN users u ON u.id=a.actor_id WHERE " <>
        where,
      args,
      "occurred_at DESC,id",
      page(p),
      24
    )
  end

  def run("audit_get", %{"id" => id}) do
    with {:ok, [entry]} <-
           DB.execute(
             "SELECT a.*,COALESCE(u.name,s.label) AS actor_name,u.email AS actor_email FROM audit_actions a JOIN actors s ON s.id=a.actor_id LEFT JOIN users u ON u.id=a.actor_id WHERE a.id=?",
             [id]
           ),
         {:ok, rows} <-
           DB.execute(
             "SELECT r.id,r.table_name,r.operation,v.column_name,v.old_type,v.old_value,v.new_type,v.new_value FROM audit_rows r LEFT JOIN audit_values v ON v.row_id=r.id WHERE r.action_id=? ORDER BY r.id,v.column_name",
             [id]
           ) do
      {:ok, Map.put(entry, "changes", rows)}
    else
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  defp page(p) do
    case Integer.parse(to_string(p["page"] || 1)) do
      {n, ""} when n > 0 -> min(n, 100_000)
      _ -> 1
    end
  end

  defp end_date(nil), do: nil
  defp end_date(""), do: nil

  defp end_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date |> Date.add(1) |> Date.to_iso8601()
      _ -> nil
    end
  end
end
