defmodule Gcf.Admin.Page do
  alias Gcf.Database, as: DB

  def fetch(select, params, order, page, size) do
    with {:ok, rows} <-
           DB.execute(
             "SELECT *, COUNT(*) OVER() AS result_count FROM (#{select}) ORDER BY #{order} LIMIT ? OFFSET ?",
             params ++ [size, (page - 1) * size]
           ),
         {:ok, total} <- total(rows, select, params) do
      {:ok,
       %{
         items: Enum.map(rows, &Map.delete(&1, "result_count")),
         total: total,
         page: page,
         page_size: size,
         more: page * size < total
       }}
    end
  end

  defp total([row | _], _select, _params), do: {:ok, row["result_count"]}

  defp total([], select, params) do
    with {:ok, [row]} <- DB.execute("SELECT COUNT(*) AS total FROM (#{select})", params),
         do: {:ok, row["total"]}
  end
end
