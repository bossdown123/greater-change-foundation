defmodule Gcf.Admin.Drafts do
  alias Gcf.Admin.{Content, Mutation}
  @kinds ~w(events initiatives campaigns newsletters articles media_groups)
  def create(%{"collection" => kind, "draft_id" => id}, actor)
      when kind in @kinds and is_binary(id) do
    if Regex.match?(~r/^[a-f0-9]{32}$/, id) do
      case existing(kind, id, actor) do
        {:ok, :new} ->
          Mutation.target(kind, id, title(kind))

          result =
            Content.run("save", %{"collection" => kind, "new_id" => id, "data" => defaults(kind)})

          case result do
            {:error, _} ->
              case existing(kind, id, actor) do
                {:ok, :existing} -> Content.run("get", %{"collection" => kind, "id" => id})
                _ -> result
              end

            _ ->
              result
          end

        {:ok, :existing} ->
          Content.run("get", %{"collection" => kind, "id" => id})

        error ->
          error
      end
    else
      {:error, "Invalid draft identifier"}
    end
  end

  def create(_, _), do: {:error, "Invalid draft type"}

  defp existing(kind, id, actor) do
    case Gcf.Database.execute("SELECT created_by FROM #{kind}_attribution WHERE record_id=?", [id]) do
      {:ok, []} ->
        {:ok, :new}

      {:ok, [%{"created_by" => creator}]} ->
        if creator == actor["id"], do: {:ok, :existing}, else: {:error, :forbidden}

      error ->
        error
    end
  end

  defp title("media_groups"), do: "Untitled collection"
  defp title("events"), do: "Untitled activity"
  defp title("initiatives"), do: "Untitled campaign"
  defp title("campaigns"), do: "Untitled fundraiser"
  defp title("articles"), do: "Untitled article"
  defp title("newsletters"), do: "Untitled newsletter"

  defp defaults(kind) when kind in ~w(newsletters articles),
    do: %{
      "title" => title(kind),
      "subject" => title(kind),
      "introduction" => "",
      "body" => "",
      "updates" => []
    }

  defp defaults(kind), do: %{"title" => title(kind), "summary" => ""}
end
