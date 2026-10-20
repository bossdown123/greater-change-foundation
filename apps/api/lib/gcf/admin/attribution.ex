defmodule Gcf.Admin.Attribution do
  @tables ~w(events initiatives campaigns newsletters media)
  def attach({:ok, %{items: rows} = result}, table) when table in @tables do
    {:ok, %{result | items: rows(rows, table)}}
  end

  def attach({:ok, %{"id" => _} = row}, table) when table in @tables do
    {:ok, hd(rows([row], table))}
  end

  def attach(result, _), do: result

  defp rows([], _), do: []

  defp rows(rows, table) do
    ids = Enum.map(rows, & &1["id"])
    placeholders = Enum.map_join(ids, ",", fn _ -> "?" end)

    {:ok, owners} =
      Gcf.Database.execute(
        "SELECT a.*,COALESCE(c.name,ca.label) AS creator_name,COALESCE(m.name,ma.label) AS modifier_name FROM #{table}_attribution a JOIN actors ca ON ca.id=a.created_by LEFT JOIN users c ON c.id=a.created_by JOIN actors ma ON ma.id=a.updated_by LEFT JOIN users m ON m.id=a.updated_by WHERE a.record_id IN (#{placeholders})",
        ids
      )

    by_id = Map.new(owners, &{&1["record_id"], Map.delete(&1, "record_id")})
    result = Enum.map(rows, &Map.merge(&1, Map.get(by_id, &1["id"], %{})))
    if table == "media", do: Gcf.Admin.MediaMetadata.attach(result), else: result
  end
end
