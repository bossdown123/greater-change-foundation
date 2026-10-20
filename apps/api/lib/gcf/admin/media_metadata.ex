defmodule Gcf.Admin.MediaMetadata do
  alias Gcf.Database, as: DB

  @tables ~w(media_dimensions media_captures media_coordinates media_place_names media_metadata_scans)

  def read(path) do
    task =
      Task.async(fn ->
        try do
          System.cmd("exiftool", [
            "-json",
            "-n",
            "-DateTimeOriginal",
            "-OffsetTimeOriginal",
            "-CreateDate",
            "-OffsetTimeDigitized",
            "-GPSDateTime",
            "-GPSLatitude",
            "-GPSLatitudeRef",
            "-GPSLongitude",
            "-GPSLongitudeRef",
            "-GPSAltitude",
            "-ImageWidth",
            "-ImageHeight",
            "-Orientation",
            "-Location",
            "-Sub-location",
            "-City",
            "-State",
            "-Country",
            "-Country-PrimaryLocationName",
            "--",
            path
          ])
        rescue
          _ -> {"", 1}
        end
      end)

    case Task.yield(task, 15_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {json, 0}} -> with {:ok, [tags]} <- Jason.decode(json), do: {:ok, normalise(tags)}
      _ -> {:error, "Image metadata could not be read"}
    end
  end

  def normalise(tags) do
    capture =
      Enum.find_value(
        [
          {tags["DateTimeOriginal"], tags["OffsetTimeOriginal"], "original"},
          {tags["CreateDate"], tags["OffsetTimeDigitized"], "created"},
          {tags["GPSDateTime"], "+00:00", "gps"}
        ],
        fn {value, offset, source} ->
          case parse_time(value, offset) do
            nil -> nil
            result -> Map.put(result, :source, source)
          end
        end
      )

    width = number(tags["ImageWidth"])
    height = number(tags["ImageHeight"])

    dimensions =
      if width && height && width > 0 && height > 0 do
        if tags["Orientation"] in [5, 6, 7, 8],
          do: %{width: trunc(height), height: trunc(width)},
          else: %{width: trunc(width), height: trunc(height)}
      end

    lat = coordinate(tags["GPSLatitude"], tags["GPSLatitudeRef"], 90)
    lon = coordinate(tags["GPSLongitude"], tags["GPSLongitudeRef"], 180)

    coords =
      if is_number(lat) && is_number(lon),
        do: %{latitude: lat, longitude: lon, altitude: number(tags["GPSAltitude"])}

    places =
      for {kind, value} <- [
            {"location", tags["Location"] || tags["Sub-location"]},
            {"city", tags["City"]},
            {"region", tags["State"]},
            {"country", tags["Country"] || tags["Country-PrimaryLocationName"]}
          ],
          is_binary(value),
          String.trim(value) != "",
          into: %{},
          do: {kind, String.slice(String.trim(value), 0, 300)}

    %{capture: capture, dimensions: dimensions, coordinates: coords, places: places}
  end

  def parse_time(value, offset) when is_binary(value) do
    case Regex.run(
           ~r/^(\d{4})[:-](\d{2})[:-](\d{2})[ T](\d{2}:\d{2}:\d{2}(?:\.\d+)?)(Z|[+-]\d{2}:?\d{2})?$/,
           value
         ) do
      [_, y, m, d, time | zone] ->
        case NaiveDateTime.from_iso8601("#{y}-#{m}-#{d}T#{time}") do
          {:ok, date} ->
            %{
              local_datetime: NaiveDateTime.to_iso8601(date),
              utc_offset_minutes: offset_minutes(Enum.find(zone, &(&1 != "")) || offset)
            }

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def parse_time(_, _), do: nil
  defp offset_minutes("Z"), do: 0

  defp offset_minutes(value) when is_binary(value) do
    case Regex.run(~r/^([+-])(\d{2}):?(\d{2})$/, value) do
      [_, sign, h, m] ->
        minutes = String.to_integer(h) * 60 + String.to_integer(m)

        if String.to_integer(m) < 60 && minutes <= 840,
          do: minutes * if(sign == "-", do: -1, else: 1)

      _ ->
        nil
    end
  end

  defp offset_minutes(_), do: nil
  defp number(n) when is_number(n), do: n

  defp number(s) when is_binary(s) do
    case Float.parse(s) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp number(_), do: nil

  defp coordinate(value, ref, max) do
    case number(value) do
      n when is_number(n) and n >= -max and n <= max ->
        if ref in ["S", "W", "South", "West"], do: -abs(n), else: n

      _ ->
        nil
    end
  end

  def statements(id, data) do
    cleanup = Enum.map(@tables, &{"DELETE FROM #{&1} WHERE media_id=?", [id]})

    dim =
      if d = data.dimensions,
        do: [{"INSERT INTO media_dimensions VALUES(?,?,?)", [id, d.width, d.height]}],
        else: []

    capture =
      if c = data.capture,
        do: [
          {"INSERT INTO media_captures VALUES(?,?,?,?)",
           [id, c.local_datetime, c.utc_offset_minutes, c.source]}
        ],
        else: []

    coords =
      if c = data.coordinates,
        do: [
          {"INSERT INTO media_coordinates VALUES(?,?,?,?)",
           [id, c.latitude, c.longitude, c.altitude]}
        ],
        else: []

    places =
      Enum.map(data.places, fn {kind, name} ->
        {"INSERT INTO media_place_names VALUES(?,?,?)", [id, kind, name]}
      end)

    cleanup ++
      dim ++
      capture ++
      coords ++
      places ++
      [
        {"INSERT INTO media_metadata_scans VALUES(?,?)",
         [id, DateTime.to_iso8601(DateTime.utc_now())]}
      ]
  end

  def refresh(id) do
    with {:ok, bytes, _} <- Gcf.Admin.Content.file(id, false) do
      path =
        Path.join(
          System.tmp_dir!(),
          "gcf-metadata-" <> Base.encode16(:crypto.strong_rand_bytes(16))
        )

      try do
        File.write!(path, bytes)
        File.chmod!(path, 0o600)

        with {:ok, data} <- read(path),
             {:ok, _} <- DB.batch(statements(id, data)),
             do: Gcf.Admin.Content.run("media_get", %{"id" => id})
      after
        File.rm(path)
      end
    end
  end

  def filter(p) do
    q = "%" <> String.slice(to_string(p["query"] || ""), 0, 200) <> "%"

    sql =
      "(m.filename LIKE ? OR m.caption LIKE ? OR m.alt LIKE ? OR EXISTS(SELECT 1 FROM media_place_names pn WHERE pn.media_id=m.id AND pn.name LIKE ?) OR EXISTS(SELECT 1 FROM media_captures mc WHERE mc.media_id=m.id AND mc.local_datetime LIKE ?) OR EXISTS(SELECT 1 FROM media_coordinates g WHERE g.media_id=m.id AND (CAST(g.latitude AS TEXT)||','||CAST(g.longitude AS TEXT)) LIKE ?))"

    args = List.duplicate(q, 6)

    cond do
      p["undated"] == "1" ->
        {sql <> " AND NOT EXISTS(SELECT 1 FROM media_captures c WHERE c.media_id=m.id)", args}

      valid_date?(p["from"]) && valid_date?(p["to"]) ->
        date_filter =
          "EXISTS(SELECT 1 FROM media_captures c WHERE c.media_id=m.id AND substr(c.local_datetime,1,10)>=? AND substr(c.local_datetime,1,10)<=?)"

        date_filter =
          if p["include_undated"] == "1",
            do:
              "(" <>
                date_filter <>
                " OR NOT EXISTS(SELECT 1 FROM media_captures c WHERE c.media_id=m.id))",
            else: date_filter

        {sql <> " AND " <> date_filter, args ++ [p["from"], p["to"]]}

      true ->
        {sql, args}
    end
  end

  defp valid_date?(s) when is_binary(s), do: match?({:ok, _}, Date.from_iso8601(s))
  defp valid_date?(_), do: false

  def summary(p) do
    {where, args} = filter(p)

    with {:ok, [summary]} <-
           DB.execute(
             "SELECT (SELECT count(*) FROM media) AS total,(SELECT count(*) FROM media_captures) AS dated,(SELECT count(*) FROM media_metadata_scans) AS scanned,(SELECT count(*) FROM media_coordinates) AS gps_count,min(substr(local_datetime,1,10)) AS first_date,max(substr(local_datetime,1,10)) AS last_date FROM media_captures"
           ),
         {:ok, places} <-
           DB.execute(
             "SELECT pn.name,count(DISTINCT m.id) AS count FROM media m JOIN media_place_names pn ON pn.media_id=m.id WHERE (#{where}) AND pn.kind IN ('city','location') GROUP BY pn.name ORDER BY count DESC,pn.name LIMIT 3",
             args
           ) do
      {:ok, Map.put(summary, "places", places)}
    end
  end

  def attach([]), do: []

  def attach(rows) do
    ids = Enum.map(rows, & &1["id"])
    slots = Enum.map_join(ids, ",", fn _ -> "?" end)

    {:ok, metadata} =
      DB.execute(
        "SELECT m.id,d.width,d.height,c.local_datetime,c.utc_offset_minutes,c.source,g.latitude,g.longitude,g.altitude FROM media m LEFT JOIN media_dimensions d ON d.media_id=m.id LEFT JOIN media_captures c ON c.media_id=m.id LEFT JOIN media_coordinates g ON g.media_id=m.id WHERE m.id IN (#{slots})",
        ids
      )

    {:ok, places} =
      DB.execute("SELECT * FROM media_place_names WHERE media_id IN (#{slots})", ids)

    lookup = Map.new(metadata, &{&1["id"], Map.delete(&1, "id")})

    Enum.map(rows, fn row ->
      names =
        for place <- places,
            place["media_id"] == row["id"],
            into: %{},
            do: {place["kind"], place["name"]}

      Map.put(row, "metadata", Map.put(lookup[row["id"]] || %{}, "places", names))
    end)
  end
end
