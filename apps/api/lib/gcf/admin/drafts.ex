defmodule Gcf.Admin.Drafts do
  alias Gcf.Admin.{Content, Mutation}
  @kinds ~w(events initiatives campaigns newsletters)
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

  defp title("events"), do: "Untitled event"
  defp title("initiatives"), do: "Untitled initiative"
  defp title("campaigns"), do: "Untitled campaign"
  defp title("newsletters"), do: "Untitled newsletter"

  defp defaults("newsletters"),
    do: %{
      "title" => title("newsletters"),
      "subject" => "Untitled newsletter",
      "introduction" => "",
      "body" => "",
      "updates" => []
    }

  defp defaults(kind), do: %{"title" => title(kind), "summary" => ""}
end
