defmodule Gcf.Admin.Content do
  alias Gcf.Database, as: DB
  @collections ~w(events newsletters articles)
  def run(operation, %{"collection" => kind} = params) when kind in ["initiatives", "campaigns"],
    do: Gcf.Admin.Programs.run(operation, params)

  def run("list", %{"collection" => collection} = p) when collection in @collections do
    page = max(1, min(integer(p["page"], 1), 100_000))
    query = String.slice(to_string(p["query"] || ""), 0, 200)

    with {:ok, result} <-
           Gcf.Admin.Page.fetch(
             "SELECT * FROM #{collection} WHERE title LIKE ?",
             ["%#{query}%"],
             "updated_at DESC, id",
             page,
             24
           ) do
      {:ok, %{result | items: hydrate!(collection, result.items)}}
    end
  end

  def run("get", %{"collection" => collection, "id" => id}) when collection in @collections do
    with {:ok, row} <- get(collection, id), do: {:ok, hd(hydrate!(collection, [row]))}
  end

  def run("save", %{"collection" => collection, "data" => data} = p)
      when collection in @collections and is_map(data) do
    with {:ok, data} <- validate(collection, data),
         {:ok, id} <- if(p["new_id"], do: {:ok, p["new_id"]}, else: save_id(collection, p["id"])) do
      Gcf.Admin.Mutation.target(collection, id, data["title"])
      now = DateTime.utc_now() |> DateTime.to_iso8601()

      statements =
        save_statements(collection, id, data, now) ++
          Gcf.Admin.RichText.statements(collection, id, data)

      statements =
        if collection == "events",
          do:
            statements ++
              event_links("initiative", id, data["initiative_ids"]) ++
              event_links("campaign", id, data["campaign_ids"]),
          else: statements

      with {:ok, _} <- DB.batch(statements),
           do: run("get", %{"collection" => collection, "id" => id})
    end
  end

  def run("delete", %{"collection" => collection, "id" => id}) when collection in @collections do
    with {:ok, _} <- get(collection, id),
         {:ok, _} <-
           DB.execute(
             "DELETE FROM #{if collection in ~w(newsletters articles), do: "publications", else: collection} WHERE id = ?",
             [id]
           ),
         do: {:ok, %{deleted: true}}
  end

  def run("list_work", p) do
    page = max(1, min(integer(p["page"], 1), 100_000))
    kind = if p["kind"] in ~w(events initiatives campaigns), do: p["kind"], else: "%"
    query = "%" <> String.slice(to_string(p["query"] || ""), 0, 200) <> "%"

    Gcf.Admin.Page.fetch(
      "SELECT * FROM work_records WHERE title LIKE ? AND kind LIKE ?",
      [query, kind],
      "updated_at DESC,kind,id",
      page,
      24
    )
  end

  def run("list_updates", p) do
    page = max(1, min(integer(p["page"], 1), 100_000))
    kind = if p["kind"] in ["events", "initiatives", "campaigns"], do: p["kind"], else: "%"
    query = "%" <> String.slice(to_string(p["query"] || ""), 0, 200) <> "%"

    sql =
      "SELECT * FROM (SELECT id,title,summary,updated_at,'events' AS kind FROM events UNION ALL SELECT id,title,summary,updated_at,'initiatives' AS kind FROM initiatives UNION ALL SELECT id,title,summary,updated_at,'campaigns' AS kind FROM campaigns) WHERE title LIKE ? AND kind LIKE ?"

    Gcf.Admin.Page.fetch(sql, [query, kind], "updated_at DESC,id", page, 24)
  end

  def run("media_list", p) do
    page = max(1, min(integer(p["page"], 1), 100_000))
    {where, args} = Gcf.Admin.MediaMetadata.filter(p)

    with {:ok, result} <-
           Gcf.Admin.Page.fetch(
             "SELECT m.*,(#{Gcf.Admin.RichText.usage_sql()}) AS uses FROM media m WHERE " <>
               where,
             args,
             "created_at DESC,id",
             page,
             48
           ) do
      {:ok, %{result | items: Enum.map(result.items, &media_view/1)}}
    end
  end

  def run("media_get", %{"id" => id}) do
    with {:ok, row} <- get("media", id),
         {:ok, uses} <-
           DB.execute(
             "SELECT e.id,e.title FROM events e JOIN event_media em ON em.event_id=e.id WHERE em.media_id=?",
             [id]
           ),
         {:ok, [%{"uses" => count}]} <-
           DB.execute(
             "SELECT (#{Gcf.Admin.RichText.usage_sql()}) AS uses FROM media m WHERE m.id=?",
             [id]
           ) do
      {:ok, media_view(row) |> Map.put("events", uses) |> Map.put("uses", count)}
    end
  end

  def run("media_update", %{"id" => id} = p) do
    with true <- valid_text?(p["alt"], 1000) and valid_text?(p["caption"], 2000),
         {:ok, _} <- get("media", id),
         {:ok, _} <-
           DB.execute("UPDATE media SET alt=?,caption=? WHERE id=?", [p["alt"], p["caption"], id]) do
      run("media_get", %{"id" => id})
    else
      false -> {:error, "Alt text or caption is too long"}
      error -> error
    end
  end

  def run("media_delete", %{"id" => id}) do
    with {:ok, row} <- get("media", id),
         {:ok, [%{"uses" => 0}]} <-
           DB.execute(
             "SELECT (#{Gcf.Admin.RichText.usage_sql()}) AS uses FROM media m WHERE m.id=?",
             [id]
           ),
         {:ok, deleted} <-
           DB.execute(
             "DELETE FROM media WHERE id=? AND NOT EXISTS(SELECT 1 FROM event_media WHERE media_id=?) RETURNING id",
             [id, id]
           ),
         true <- deleted != [] do
      Gcf.Admin.Storage.request(:delete, row["storage_key"])
      Gcf.Admin.Storage.request(:delete, row["thumbnail_key"])
      {:ok, %{deleted: true}}
    else
      {:ok, _} -> {:error, "Remove this image from its events before deleting it"}
      false -> {:error, "This image is in use"}
      error -> error
    end
  end

  def run("generate", params) do
    updates = updates(params)

    with true <- length(updates) in 1..60,
         :ok <- valid_updates(updates),
         {:ok, sections} <- newsletter_sections(updates) do
      {:ok,
       %{
         title: "GCF newsletter",
         subject: "Greater Change Foundation — news from our community",
         introduction: "Here is the latest from Greater Change Foundation.",
         body: Enum.join(sections, "\n\n—\n\n"),
         updates: updates,
         event_ids: for(u <- updates, u["kind"] == "events", do: u["id"])
       }}
    else
      false -> {:error, "Choose between 1 and 60 updates"}
      error -> error
    end
  end

  def run(_, _), do: {:error, "Invalid request"}

  def upload(%Plug.Upload{} = file, p) do
    with {:ok, %{size: size}} <- File.stat(file.path),
         true <- size in 1..33_554_432,
         {:ok, bytes} <- File.read(file.path),
         {:ok, mime, ext} <- image_type(bytes),
         {:ok, metadata} <- Gcf.Admin.MediaMetadata.read(file.path),
         {:ok, thumb} <- thumbnail(file.path),
         id = uuid(),
         :ok <- Gcf.Admin.Mutation.target("media", id, Path.basename(file.filename)),
         key = "media/#{id}/original.#{ext}",
         thumbnail_key = "media/#{id}/thumbnail.webp",
         {:ok, _} <- Gcf.Admin.Storage.request(:put, key, bytes, mime),
         {:ok, _} <- Gcf.Admin.Storage.request(:put, thumbnail_key, thumb, "image/webp") do
      alt = String.slice(to_string(p["alt"] || ""), 0, 1000)
      caption = String.slice(to_string(p["caption"] || ""), 0, 2000)
      filename = Path.basename(file.filename) |> String.slice(0, 240)

      case DB.batch(
             [
               {
                 "INSERT INTO media(id,filename,mime_type,size_bytes,storage_key,thumbnail_key,alt,caption,created_at) VALUES(?,?,?,?,?,?,?,?,?)",
                 [
                   id,
                   filename,
                   mime,
                   size,
                   key,
                   thumbnail_key,
                   alt,
                   caption,
                   DateTime.to_iso8601(DateTime.utc_now())
                 ]
               }
             ] ++ Gcf.Admin.MediaMetadata.statements(id, metadata)
           ) do
        {:ok, _} ->
          run("media_get", %{"id" => id})

        error ->
          Gcf.Admin.Storage.request(:delete, key)
          Gcf.Admin.Storage.request(:delete, thumbnail_key)
          error
      end
    else
      false -> {:error, "Choose an image no larger than 32 MB"}
      error -> error
    end
  end

  def upload(_, _), do: {:error, "Choose a JPEG, PNG or WebP image"}

  def file(id, thumbnail?) do
    with {:ok, row} <- get("media", id),
         key = row[if(thumbnail?, do: "thumbnail_key", else: "storage_key")],
         {:ok, bytes} <- Gcf.Admin.Storage.request(:get, key) do
      {:ok, bytes, if(thumbnail?, do: "image/webp", else: row["mime_type"])}
    end
  end

  def validate("events", d) do
    data = %{
      "title" => d["title"],
      "summary" => d["summary"] || "",
      "dates" => d["dates"] || [],
      "locations" => d["locations"] || [],
      "participants" => blank_nil(d["participants"]),
      "funds_raised" => blank_nil(d["funds_raised"]),
      "currency" => d["currency"] || "USD",
      "custom_fields" => d["custom_fields"] || [],
      "media_ids" => d["media_ids"] || [],
      "initiative_ids" => d["initiative_ids"],
      "campaign_ids" => d["campaign_ids"]
    }

    cond do
      not valid_text?(data["title"], 200, true) ->
        {:error, "An event title is required (up to 200 characters)"}

      not Gcf.Admin.RichText.valid?(data["summary"], 10_000) ->
        {:error, "Story formatting is invalid or the story is too long"}

      not list_of?(data["dates"], 30, &date?/1) or
          length(Enum.uniq(data["dates"])) != length(data["dates"]) ->
        {:error, "Use valid dates"}

      not list_of?(data["locations"], 30, &valid_text?(&1, 300, true)) or
          length(Enum.uniq(data["locations"])) != length(data["locations"]) ->
        {:error, "Check the locations"}

      not optional_number?(data["participants"], true) ->
        {:error, "Participants must be a non-negative whole number"}

      not optional_number?(data["funds_raised"], false) ->
        {:error, "Funds raised must be a non-negative number"}

      not (is_binary(data["currency"]) and Regex.match?(~r/^[A-Z]{3}$/, data["currency"])) ->
        {:error, "Use a three-letter currency code"}

      not list_of?(data["custom_fields"], 40, &fact?/1) or
          duplicate_fields?(data["custom_fields"]) ->
        {:error, "Check additional fact labels, types and values"}

      not list_of?(data["media_ids"], 100, &id?/1) ->
        {:error, "Choose at most 100 images"}

      length(Enum.uniq(data["media_ids"])) != length(data["media_ids"]) ->
        {:error, "An image can only appear once per event"}

      true ->
        with {:ok, _} <- load_media(data["media_ids"]),
             :ok <- optional_links("initiatives", data["initiative_ids"]),
             :ok <- optional_links("campaigns", data["campaign_ids"]),
             do: {:ok, data}
    end
  end

  def validate("articles", d), do: validate("newsletters", d)

  def validate("newsletters", d) do
    data = Map.take(d, ~w(title subject introduction body)) |> Map.put("updates", updates(d))

    if valid_text?(data["title"], 200, true) and valid_text?(data["subject"], 300, true) and
         Gcf.Admin.RichText.valid?(data["introduction"], 10000) and
         Gcf.Admin.RichText.valid?(data["body"], 100_000) do
      with :ok <- valid_updates(data["updates"]), do: {:ok, data}
    else
      {:error, "Add a title and subject; keep the newsletter within the text limits"}
    end
  end

  defp load_events(ids) do
    with true <- Enum.all?(ids, &id?/1),
         {:ok, rows} <-
           DB.execute("SELECT * FROM events WHERE id IN (#{placeholders(ids)})", ids),
         true <- length(rows) == length(Enum.uniq(ids)) do
      events = hydrate!("events", rows) |> Map.new(&{&1["id"], &1})
      {:ok, Enum.map(ids, &events[&1])}
    else
      _ -> {:error, "A selected event no longer exists"}
    end
  end

  defp load_media(ids) do
    Enum.reduce_while(ids, {:ok, []}, fn id, {:ok, acc} ->
      case get("media", id) do
        {:ok, row} -> {:cont, {:ok, [row | acc]}}
        _ -> {:halt, {:error, "A selected image is no longer in the library"}}
      end
    end)
  end

  defp get(table, id) when table in ["events", "newsletters", "articles", "media"] do
    case DB.execute("SELECT * FROM #{table} WHERE id=?", [id]) do
      {:ok, [row]} -> {:ok, row}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  defp save_id(_, nil), do: {:ok, uuid()}

  defp save_id(table, id) do
    with {:ok, _} <- get(table, id), do: {:ok, id}
  end

  defp optional_links(_, nil), do: :ok
  defp optional_links(kind, ids), do: Gcf.Admin.Programs.check_ids(kind, ids)
  defp event_links(_, _, nil), do: []

  defp event_links(kind, event_id, ids) do
    table = kind <> "_events"
    owner = kind <> "_id"

    [
      {"DELETE FROM #{table} WHERE event_id=?" <>
         if(ids == [], do: "", else: " AND #{owner} NOT IN (#{placeholders(ids)})"),
       [event_id | ids]}
    ] ++
      Enum.map(ids, fn id ->
        {"INSERT INTO #{table}(#{owner},event_id,position) SELECT ?,?,COALESCE(MAX(position),-1)+1 FROM #{table} WHERE #{owner}=? ON CONFLICT(#{owner},event_id) DO NOTHING",
         [id, event_id, id]}
      end)
  end

  defp save_statements("events", id, data, now) do
    ([
       {"INSERT INTO events(id,title,summary,participant_count,funds_minor,currency,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,summary=excluded.summary,participant_count=excluded.participant_count,funds_minor=excluded.funds_minor,currency=excluded.currency,updated_at=excluded.updated_at",
        [
          id,
          data["title"],
          data["summary"],
          data["participants"],
          if(data["funds_raised"] != nil, do: round(data["funds_raised"] * 100)),
          data["currency"],
          now,
          now
        ]}
     ] ++
       Enum.map(
         ~w(event_dates event_locations event_field_values event_media),
         &{"DELETE FROM #{&1} WHERE event_id=?", [id]}
       ) ++
       Enum.with_index(data["dates"], fn date, position ->
         {"INSERT INTO event_dates(event_id,position,event_date) VALUES(?,?,?)",
          [id, position, date]}
       end) ++
       Enum.with_index(data["locations"], fn location, position ->
         [
           {"INSERT INTO locations(id,name) VALUES(?,?) ON CONFLICT(name) DO NOTHING",
            [uuid(), location]},
           {"INSERT INTO event_locations(event_id,location_id,position) VALUES(?,(SELECT id FROM locations WHERE name=?),?)",
            [id, location, position]}
         ]
       end))
    |> List.flatten()
    |> Kernel.++(
      Enum.with_index(data["custom_fields"], fn fact, position ->
        column =
          %{
            "text" => "text_value",
            "number" => "number_value",
            "date" => "date_value",
            "link" => "link_value"
          }[fact["type"]]

        [
          {"INSERT INTO field_definitions(id,label,kind) VALUES(?,?,?) ON CONFLICT(label,kind) DO NOTHING",
           [uuid(), fact["label"], fact["type"]]},
          {"INSERT INTO event_field_values(event_id,field_id,position,#{column}) VALUES(?,(SELECT id FROM field_definitions WHERE label=? AND kind=?),?,?)",
           [id, fact["label"], fact["type"], position, fact["value"]]}
        ]
      end)
      |> List.flatten()
    )
    |> Kernel.++(
      Enum.with_index(data["media_ids"], fn media_id, position ->
        {"INSERT INTO event_media(event_id,media_id,position) VALUES(?,?,?)",
         [id, media_id, position]}
      end)
    )
  end

  defp save_statements(kind, id, data, now) when kind in ~w(newsletters articles) do
    [
      {"INSERT INTO publications(id,title,subject,introduction,body,created_at,updated_at,format) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,subject=excluded.subject,introduction=excluded.introduction,body=excluded.body,updated_at=excluded.updated_at",
       [
         id,
         data["title"],
         data["subject"],
         data["introduction"],
         data["body"],
         now,
         now,
         if(kind == "articles", do: "article", else: "newsletter")
       ]},
      {"DELETE FROM newsletter_items WHERE newsletter_id=?", [id]}
    ] ++
      (Enum.with_index(data["updates"], fn update, position ->
         item_id = uuid()
         {table, key} = update_table(update["kind"])

         [
           {"INSERT INTO newsletter_items(id,newsletter_id,position,kind) VALUES(?,?,?,?)",
            [item_id, id, position, update["kind"]]},
           {"INSERT INTO #{table}(item_id,#{key}) VALUES(?,?)", [item_id, update["id"]]}
         ]
       end)
       |> List.flatten())
  end

  defp hydrate!(_, []), do: []

  defp hydrate!("events", rows) do
    ids = Enum.map(rows, & &1["id"])
    clause = placeholders(ids)

    {:ok, [dates, locations, facts, media, initiatives, campaigns]} =
      DB.batch([
        {"SELECT event_id,event_date FROM event_dates WHERE event_id IN (#{clause}) ORDER BY position",
         ids},
        {"SELECT e.event_id,l.name FROM event_locations e JOIN locations l ON e.location_id=l.id WHERE event_id IN (#{clause}) ORDER BY e.position",
         ids},
        {"SELECT v.*,f.label,f.kind FROM event_field_values v JOIN field_definitions f ON f.id=v.field_id WHERE event_id IN (#{clause}) ORDER BY v.position",
         ids},
        {"SELECT event_id,media_id FROM event_media WHERE event_id IN (#{clause}) ORDER BY position",
         ids},
        {"SELECT event_id,initiative_id FROM initiative_events WHERE event_id IN (#{clause}) ORDER BY initiative_id",
         ids},
        {"SELECT event_id,campaign_id FROM campaign_events WHERE event_id IN (#{clause}) ORDER BY campaign_id",
         ids}
      ])

    Enum.map(rows, fn row ->
      row
      |> Map.drop(~w(participant_count funds_minor))
      |> Map.merge(%{
        "participants" => row["participant_count"],
        "funds_raised" => if(row["funds_minor"] != nil, do: row["funds_minor"] / 100),
        "dates" => related(dates, row["id"], "event_date"),
        "locations" => related(locations, row["id"], "name"),
        "media_ids" => related(media, row["id"], "media_id"),
        "initiative_ids" => related(initiatives, row["id"], "initiative_id"),
        "campaign_ids" => related(campaigns, row["id"], "campaign_id"),
        "custom_fields" =>
          facts
          |> Enum.filter(&(&1["event_id"] == row["id"]))
          |> Enum.map(fn f ->
            %{
              "label" => f["label"],
              "type" => f["kind"],
              "value" =>
                f[
                  %{
                    "text" => "text_value",
                    "number" => "number_value",
                    "date" => "date_value",
                    "link" => "link_value"
                  }[f["kind"]]
                ]
            }
          end)
      })
    end)
  end

  defp hydrate!("articles", rows), do: hydrate!("newsletters", rows)

  defp hydrate!("newsletters", rows) do
    ids = Enum.map(rows, & &1["id"])

    {:ok, links} =
      DB.execute(
        "SELECT i.newsletter_id,i.kind,i.position,COALESCE(e.event_id,n.initiative_id,c.campaign_id) AS source_id FROM newsletter_items i LEFT JOIN newsletter_event_items e ON e.item_id=i.id LEFT JOIN newsletter_initiative_items n ON n.item_id=i.id LEFT JOIN newsletter_campaign_items c ON c.item_id=i.id WHERE i.newsletter_id IN (#{placeholders(ids)}) ORDER BY i.position",
        ids
      )

    Enum.map(rows, fn row ->
      updates =
        for(
          x <- links,
          x["newsletter_id"] == row["id"],
          do: %{"kind" => x["kind"], "id" => x["source_id"]}
        )

      row
      |> Map.put("updates", updates)
      |> Map.put("event_ids", for(u <- updates, u["kind"] == "events", do: u["id"]))
    end)
  end

  defp updates(d) do
    case d["updates"] do
      nil -> for id <- d["event_ids"] || [], do: %{"kind" => "events", "id" => id}
      items when is_list(items) -> items
      _ -> [%{"kind" => "invalid", "id" => ""}]
    end
  end

  defp valid_updates(items) do
    if is_list(items) and length(items) <= 60 and
         Enum.all?(items, fn x ->
           is_map(x) and x["kind"] in ["events", "initiatives", "campaigns"] and id?(x["id"])
         end) and length(Enum.uniq_by(items, &{&1["kind"], &1["id"]})) == length(items) do
      Enum.reduce_while(["events", "initiatives", "campaigns"], :ok, fn kind, _ ->
        case Gcf.Admin.Programs.check_ids(kind, for(u <- items, u["kind"] == kind, do: u["id"])) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    else
      {:error, "Choose up to 60 unique event, initiative or campaign updates"}
    end
  end

  defp newsletter_sections(updates) do
    Enum.reduce_while(updates, {:ok, []}, fn u, {:ok, sections} ->
      record =
        if u["kind"] == "events",
          do: with({:ok, [event]} <- load_events([u["id"]]), do: {:ok, event}),
          else: Gcf.Admin.Programs.get(u["kind"], u["id"])

      case record do
        {:ok, r} ->
          details =
            case u["kind"] do
              "events" ->
                [
                  Enum.join(r["dates"], " · "),
                  Enum.join(r["locations"], ", "),
                  if(r["participants"] != nil, do: "Participants: #{r["participants"]}"),
                  if(r["funds_raised"] != nil,
                    do: "Funds raised: #{r["currency"]} #{r["funds_raised"]}"
                  ),
                  Enum.map_join(r["custom_fields"], "\n", &"#{&1["label"]}: #{&1["value"]}")
                ]

              "initiatives" ->
                []

              "campaigns" ->
                [
                  if(r["raised"] != nil, do: "Raised: #{r["currency"]} #{r["raised"]}"),
                  if(r["target"] != nil, do: "Target: #{r["currency"]} #{r["target"]}"),
                  r["starts_on"],
                  r["ends_on"]
                ]
            end

          section =
            Enum.reject(
              [r["title"], Gcf.Admin.RichText.text(r["summary"]) | details],
              &(&1 in [nil, ""])
            )
            |> Enum.join("\n\n")

          {:cont, {:ok, sections ++ [section]}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp update_table("events"), do: {"newsletter_event_items", "event_id"}
  defp update_table("initiatives"), do: {"newsletter_initiative_items", "initiative_id"}
  defp update_table("campaigns"), do: {"newsletter_campaign_items", "campaign_id"}

  defp related(rows, id, column),
    do: rows |> Enum.filter(&(&1["event_id"] == id)) |> Enum.map(& &1[column])

  defp placeholders(ids), do: Enum.map_join(ids, ",", fn _ -> "?" end)

  defp media_view(row),
    do:
      Map.drop(row, ~w(storage_key thumbnail_key))
      |> Map.put("url", "/api/admin/media/#{row["id"]}/file")
      |> Map.put("thumbnail_url", "/api/admin/media/#{row["id"]}/thumbnail")

  defp list_of?(items, max, fun),
    do: is_list(items) and length(items) <= max and Enum.all?(items, fun)

  defp valid_text?(s, max, required \\ false),
    do: is_binary(s) and String.length(s) <= max and (not required or String.trim(s) != "")

  defp blank_nil(""), do: nil
  defp blank_nil(x), do: x
  defp optional_number?(nil, _), do: true

  defp optional_number?(n, whole),
    do: is_number(n) and n >= 0 and n <= 1_000_000_000_000 and (not whole or is_integer(n))

  defp integer(n, _) when is_integer(n), do: n

  defp integer(n, fallback) when is_binary(n) do
    case Integer.parse(n) do
      {n, ""} -> n
      _ -> fallback
    end
  end

  defp integer(_, fallback), do: fallback
  defp date?(s) when is_binary(s), do: match?({:ok, _}, Date.from_iso8601(s))
  defp date?(_), do: false
  defp id?(s), do: is_binary(s) and Regex.match?(~r/^[a-f0-9]{32}$/, s)

  defp fact?(%{"label" => label, "type" => type, "value" => value}) do
    valid_text?(label, 100, true) and
      case type do
        "text" ->
          valid_text?(value, 2000, true)

        "number" ->
          optional_number?(value, false) and value != nil

        "date" ->
          date?(value)

        "link" ->
          is_binary(value) and byte_size(value) <= 2000 and
            URI.parse(value).scheme in ["https", "http"] and
            URI.parse(value).host not in [nil, ""]

        _ ->
          false
      end
  end

  defp fact?(_), do: false

  defp duplicate_fields?(fields) do
    keys = Enum.map(fields, &{&1["label"], &1["type"]})
    length(Enum.uniq(keys)) != length(keys)
  end

  def uuid, do: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  def image_type(<<255, 216, 255, _::binary>>), do: {:ok, "image/jpeg", "jpg"}
  def image_type(<<137, 80, 78, 71, 13, 10, 26, 10, _::binary>>), do: {:ok, "image/png", "png"}

  def image_type(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>),
    do: {:ok, "image/webp", "webp"}

  def image_type(_), do: {:error, "Choose a valid JPEG, PNG or WebP image"}

  defp thumbnail(path) do
    output = Path.join(System.tmp_dir!(), "gcf-#{uuid()}.webp")

    try do
      case System.cmd(
             "timeout",
             [
               "20",
               "convert",
               "-limit",
               "memory",
               "64MiB",
               "-limit",
               "map",
               "128MiB",
               "-limit",
               "disk",
               "512MiB",
               "-define",
               "jpeg:size=1280x1280",
               path <> "[0]",
               "-auto-orient",
               "-strip",
               "-thumbnail",
               "640x640>",
               "-quality",
               "82",
               output
             ],
             stderr_to_stdout: true
           ) do
        {_, 0} -> File.read(output)
        _ -> {:error, "This image could not be processed"}
      end
    rescue
      _ -> {:error, "Image processing is unavailable"}
    after
      File.rm(output)
    end
  end
end
