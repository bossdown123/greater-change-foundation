defmodule Gcf.Admin.Programs do
  alias Gcf.Database, as: DB
  @kinds ~w(initiatives campaigns)
  def run("list", %{"collection" => kind} = p) when kind in @kinds do
    page =
      case Integer.parse(to_string(p["page"] || 1)) do
        {n, ""} when n > 0 -> n
        _ -> 1
      end

    with {:ok, result} <-
           Gcf.Admin.Page.fetch(
             "SELECT * FROM #{kind} WHERE title LIKE ?",
             ["%#{String.slice(to_string(p["query"] || ""), 0, 200)}%"],
             "updated_at DESC,id",
             page,
             24
           ) do
      {:ok, %{result | items: hydrate(kind, result.items)}}
    end
  end

  def run("get", %{"collection" => kind, "id" => id}) when kind in @kinds, do: get(kind, id)

  def run("delete", %{"collection" => kind, "id" => id}) when kind in @kinds do
    with {:ok, _} <- DB.execute("DELETE FROM #{kind} WHERE id=?", [id]),
         do: {:ok, %{deleted: true}}
  end

  def run("save", %{"collection" => kind, "data" => data} = p) when kind in @kinds do
    with {:ok, data} <- validate(kind, data),
         {:ok, id} <- if(p["new_id"], do: {:ok, p["new_id"]}, else: existing_id(kind, p["id"])) do
      Gcf.Admin.Mutation.target(kind, id, data["title"])
      now = DateTime.to_iso8601(DateTime.utc_now())

      base =
        if kind == "initiatives" do
          {"INSERT INTO initiatives(id,title,summary,created_at,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,summary=excluded.summary,updated_at=excluded.updated_at",
           [id, data["title"], data["summary"], now, now]}
        else
          {"INSERT INTO campaigns(id,title,summary,target_minor,raised_minor,currency,starts_on,ends_on,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,summary=excluded.summary,target_minor=excluded.target_minor,raised_minor=excluded.raised_minor,currency=excluded.currency,starts_on=excluded.starts_on,ends_on=excluded.ends_on,updated_at=excluded.updated_at",
           [
             id,
             data["title"],
             data["summary"],
             minor(data["target"]),
             minor(data["raised"]),
             data["currency"],
             data["starts_on"],
             data["ends_on"],
             now,
             now
           ]}
        end

      prefix = if kind == "initiatives", do: "initiative", else: "campaign"
      links = replace_links("#{prefix}_events", "#{prefix}_id", "event_id", id, data["event_ids"])

      links =
        if kind == "campaigns",
          do:
            links ++
              replace_links(
                "campaign_initiatives",
                "campaign_id",
                "initiative_id",
                id,
                data["initiative_ids"]
              ),
          else: links

      with {:ok, _} <- DB.batch([base | links] ++ Gcf.Admin.RichText.statements(kind, id, data)),
           do: get(kind, id)
    end
  end

  def get(kind, id) when kind in @kinds do
    case DB.execute("SELECT * FROM #{kind} WHERE id=?", [id]) do
      {:ok, [row]} -> {:ok, hd(hydrate(kind, [row]))}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  defp existing_id(_, nil), do: {:ok, Gcf.Admin.Content.uuid()}

  defp existing_id(kind, id) do
    with {:ok, _} <- get(kind, id), do: {:ok, id}
  end

  defp validate(kind, data) do
    data =
      Map.merge(
        %{
          "summary" => "",
          "event_ids" => [],
          "initiative_ids" => [],
          "currency" => "USD",
          "target" => nil,
          "raised" => nil,
          "starts_on" => nil,
          "ends_on" => nil
        },
        data
      )

    data = Map.update!(data, "starts_on", &blank/1) |> Map.update!("ends_on", &blank/1)

    cond do
      not text?(data["title"], 200, true) ->
        {:error, "A name is required (up to 200 characters)"}

      not Gcf.Admin.RichText.valid?(data["summary"], 10000) ->
        {:error, "Story is too long"}

      kind == "campaigns" and not (money?(data["target"]) and money?(data["raised"])) ->
        {:error, "Use non-negative amounts with at most two decimal places"}

      kind == "campaigns" and
          not (is_binary(data["currency"]) and Regex.match?(~r/^[A-Z]{3}$/, data["currency"])) ->
        {:error, "Use a three-letter currency code"}

      kind == "campaigns" and not (date?(data["starts_on"]) and date?(data["ends_on"])) ->
        {:error, "Use valid campaign dates"}

      kind == "campaigns" and data["starts_on"] != nil and data["ends_on"] != nil and
          data["starts_on"] > data["ends_on"] ->
        {:error, "End date must be on or after start date"}

      true ->
        with :ok <- check_ids("events", data["event_ids"]),
             :ok <-
               check_ids(
                 "initiatives",
                 if(kind == "campaigns", do: data["initiative_ids"], else: [])
               ) do
          {:ok, data}
        end
    end
  end

  def check_ids(kind, ids) when kind in ["events", "initiatives", "campaigns"] do
    if is_list(ids) and length(ids) <= 100 and
         Enum.all?(ids, &(is_binary(&1) and Regex.match?(~r/^[a-f0-9]{32}$/, &1))) and
         length(Enum.uniq(ids)) == length(ids) do
      if ids == [] do
        :ok
      else
        case DB.execute("SELECT id FROM #{kind} WHERE id IN (#{slots(ids)})", ids) do
          {:ok, rows} when length(rows) == length(ids) -> :ok
          _ -> {:error, "A linked record no longer exists"}
        end
      end
    else
      {:error, "Choose up to 100 unique linked records"}
    end
  end

  defp replace_links(table, owner, target, id, ids) do
    [{"DELETE FROM #{table} WHERE #{owner}=?", [id]}] ++
      Enum.with_index(ids, fn target_id, position ->
        {"INSERT INTO #{table}(#{owner},#{target},position) VALUES(?,?,?)",
         [id, target_id, position]}
      end)
  end

  defp hydrate(_, []), do: []

  defp hydrate(kind, rows) do
    ids = Enum.map(rows, & &1["id"])
    prefix = if kind == "initiatives", do: "initiative", else: "campaign"

    {:ok, [events, other]} =
      DB.batch([
        {"SELECT #{prefix}_id AS owner,event_id FROM #{prefix}_events WHERE #{prefix}_id IN (#{slots(ids)}) ORDER BY position",
         ids},
        if(kind == "campaigns",
          do:
            {"SELECT campaign_id AS owner,initiative_id AS related FROM campaign_initiatives WHERE campaign_id IN (#{slots(ids)}) ORDER BY position",
             ids},
          else:
            {"SELECT initiative_id AS owner,campaign_id AS related FROM campaign_initiatives WHERE initiative_id IN (#{slots(ids)}) ORDER BY campaign_id",
             ids}
        )
      ])

    Enum.map(rows, fn row ->
      row =
        if kind == "campaigns",
          do:
            row
            |> Map.drop(~w(target_minor raised_minor))
            |> Map.put("target", amount(row["target_minor"]))
            |> Map.put("raised", amount(row["raised_minor"])),
          else: row

      row
      |> Map.put("event_ids", for(x <- events, x["owner"] == row["id"], do: x["event_id"]))
      |> Map.put(
        if(kind == "campaigns", do: "initiative_ids", else: "campaign_ids"),
        for(x <- other, x["owner"] == row["id"], do: x["related"])
      )
    end)
  end

  defp text?(s, max, required),
    do: is_binary(s) and String.length(s) <= max and (not required or String.trim(s) != "")

  defp date?(nil), do: true
  defp date?(s) when is_binary(s), do: match?({:ok, _}, Date.from_iso8601(s))
  defp date?(_), do: false
  defp blank(""), do: nil
  defp blank(x), do: x
  defp money?(nil), do: true

  defp money?(x),
    do:
      is_number(x) and x >= 0 and x <= 1_000_000_000_000 and
        abs(x * 100 - round(x * 100)) < 0.00001

  defp minor(nil), do: nil
  defp minor(x), do: round(x * 100)
  defp amount(nil), do: nil
  defp amount(x), do: x / 100
  defp slots(ids), do: Enum.map_join(ids, ",", fn _ -> "?" end)
end
