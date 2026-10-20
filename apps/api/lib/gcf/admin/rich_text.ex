defmodule Gcf.Admin.RichText do
  @moduledoc "Validated authored documents; image relationships are materialized with foreign keys."
  @prefix "gcf-richtext:"
  @nodes ~w(doc paragraph heading bulletList orderedList listItem blockquote hardBreak horizontalRule gcfFigure text)
  @marks ~w(bold italic underline strike code link)
  def valid?(value, limit) when is_binary(value) do
    case decode(value) do
      {:ok, doc} ->
        byte_size(value) <= 600_000 and valid_node?(doc, 0) and doc["type"] == "doc" and
          String.length(text_node(doc)) <= limit and length(images(doc)) <= 100

      :plain ->
        String.length(value) <= limit

      _ ->
        false
    end
  end

  def valid?(_, _), do: false
  def decode(@prefix <> json), do: Jason.decode(json)
  def decode(_), do: :plain

  def text(value) when is_binary(value) do
    case decode(value) do
      {:ok, doc} -> text_node(doc) |> String.trim()
      _ -> value
    end
  end

  def text(_), do: ""

  def media_ids(value) do
    case decode(value) do
      {:ok, doc} -> images(doc) |> Enum.uniq()
      _ -> []
    end
  end

  def statements(kind, id, data) when kind in ~w(events initiatives campaigns newsletters) do
    {table, key} = table(kind)
    fields = if kind == "newsletters", do: ~w(introduction body), else: ["summary"]

    [{"DELETE FROM #{table} WHERE #{key}=?", [id]}] ++
      Enum.flat_map(fields, fn field ->
        Enum.map(media_ids(data[field]), fn image ->
          if kind == "newsletters",
            do: {"INSERT INTO #{table}(#{key},media_id,field) VALUES(?,?,?)", [id, image, field]},
            else: {"INSERT INTO #{table}(#{key},media_id) VALUES(?,?)", [id, image]}
        end)
      end)
  end

  def usage_sql(alias_name \\ "m") do
    [
      "event_media",
      "event_inline_media",
      "initiative_inline_media",
      "campaign_inline_media",
      "newsletter_inline_media"
    ]
    |> Enum.map_join("+", fn table ->
      "(SELECT COUNT(*) FROM #{table} WHERE media_id=#{alias_name}.id)"
    end)
  end

  defp table("events"), do: {"event_inline_media", "event_id"}
  defp table("initiatives"), do: {"initiative_inline_media", "initiative_id"}
  defp table("campaigns"), do: {"campaign_inline_media", "campaign_id"}
  defp table("newsletters"), do: {"newsletter_inline_media", "newsletter_id"}

  defp valid_node?(node, depth) when is_map(node) and depth < 20 do
    type = node["type"]
    children = node["content"] || []
    marks = node["marks"] || []
    attrs = node["attrs"] || %{}

    type in @nodes and is_list(children) and length(children) <= 2000 and is_list(marks) and
      length(marks) <= 8 and is_map(attrs) and
      (type != "text" or is_binary(node["text"])) and valid_attrs?(type, attrs) and
      Enum.all?(marks, &valid_mark?/1) and valid_children?(type, children) and
      Enum.all?(children, &valid_node?(&1, depth + 1))
  end

  defp valid_node?(_, _), do: false

  defp valid_children?(type, children) when type in ["text", "hardBreak", "horizontalRule"],
    do: children == []

  defp valid_children?(type, children) when type in ["paragraph", "heading", "gcfFigure"],
    do: Enum.all?(children, &(is_map(&1) and &1["type"] in ["text", "hardBreak"]))

  defp valid_children?(type, children) when type in ["bulletList", "orderedList"],
    do: Enum.all?(children, &(is_map(&1) and &1["type"] == "listItem"))

  defp valid_children?(_, children),
    do:
      Enum.all?(
        children,
        &(is_map(&1) and
            &1["type"] in [
              "paragraph",
              "heading",
              "bulletList",
              "orderedList",
              "blockquote",
              "horizontalRule",
              "gcfFigure"
            ])
      )

  defp valid_attrs?("gcfFigure", attrs),
    do:
      is_binary(attrs["mediaId"]) and Regex.match?(~r/^[a-f0-9]{32}$/, attrs["mediaId"]) and
        is_binary(attrs["alt"] || "") and String.length(attrs["alt"] || "") <= 1000 and
        (attrs["widthPercent"] == nil or
           (is_integer(attrs["widthPercent"]) and attrs["widthPercent"] in 1..100))

  defp valid_attrs?("heading", attrs), do: attrs["level"] in [2, 3] and valid_align?(attrs)
  defp valid_attrs?("paragraph", attrs), do: valid_align?(attrs)
  defp valid_attrs?(_, _), do: true
  defp valid_align?(attrs), do: attrs["textAlign"] in [nil, "left", "center", "right"]
  defp valid_mark?(%{"type" => "link", "attrs" => %{"href" => href}}), do: safe_link?(href)
  defp valid_mark?(%{"type" => type}), do: type in @marks and type != "link"
  defp valid_mark?(_), do: false

  defp safe_link?(href) when is_binary(href),
    do: byte_size(href) <= 2000 and Regex.match?(~r/^(https?:\/\/|mailto:)/i, href)

  defp safe_link?(_), do: false
  defp text_node(%{"type" => "hardBreak"}), do: "\n"
  defp text_node(%{"type" => "text", "text" => text}) when is_binary(text), do: text

  defp text_node(node) when is_map(node),
    do:
      Enum.map_join(
        node["content"] || [],
        if(node["type"] in ["paragraph", "heading", "gcfFigure"], do: "", else: "\n"),
        &text_node/1
      )

  defp text_node(_), do: ""

  defp images(node) when is_map(node),
    do:
      if(node["type"] == "gcfFigure", do: [get_in(node, ["attrs", "mediaId"])], else: []) ++
        Enum.flat_map(node["content"] || [], &images/1)

  defp images(_), do: []
end
