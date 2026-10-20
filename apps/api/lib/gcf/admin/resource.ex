defmodule Gcf.Admin.Resource do
  use Ash.Resource, domain: Gcf.Foundation
  alias Gcf.Admin.{Accounts, Audit, Content, Mutation}

  actions do
    action :run, :map do
      argument(:operation, :string, allow_nil?: false)
      argument(:params, :map, default: %{})

      run(fn input, context ->
        dispatch(input.arguments.operation, input.arguments.params, context.actor)
      end)
    end
  end

  defp dispatch("sign_in", p, _actor) do
    with {:ok, user} <- Accounts.authenticate(p["email"], p["password"]),
         :ok <-
           Mutation.run(user, "sign_in", %{}, fn ->
             Mutation.target("users", user["id"], user["name"])
             Mutation.activity()
           end) do
      {:ok, %{user: Accounts.public(user), session_version: user["session_version"]}}
    end
  end

  defp dispatch(operation, p, %{"id" => _, "role" => role} = actor)
       when role in ["administrator", "editor"] do
    if operation in ["list_users", "get_user", "save_user"] and role != "administrator" do
      {:error, Ash.Error.Forbidden.exception([])}
    else
      Mutation.run(actor, operation, p, fn ->
        prepare_target(operation, p)

        result =
          case operation do
            "create_draft" ->
              Gcf.Admin.Drafts.create(p, actor)

            "sign_out" ->
              with :ok <- Mutation.activity(), do: {:ok, %{signed_out: true}}

            op when op in ["list_users", "get_user", "save_user", "change_password"] ->
              Accounts.run(op, p, actor)

            op when op in ["audit_list", "audit_get"] ->
              Audit.run(op, p)

            "media_summary" ->
              Gcf.Admin.MediaMetadata.summary(p)

            "media_metadata" ->
              Gcf.Admin.MediaMetadata.refresh(p["id"])

            "list_actors" ->
              Gcf.Admin.Audit.actors()

            "upload" ->
              Content.upload(p["file"], p)

            "generate" ->
              with {:ok, data} <- Content.run(operation, p),
                   :ok <- Mutation.activity(),
                   do: {:ok, data}

            _ ->
              Content.run(operation, p)
          end

        type =
          p["collection"] ||
            if(operation == "upload" or String.starts_with?(operation, "media_"), do: "media")

        result |> Gcf.Admin.Attribution.attach(type) |> Gcf.Admin.ImageGroups.attach(type)
      end)
    end
  end

  defp dispatch(_, _, _), do: {:error, "Administrator access required"}

  defp prepare_target(operation, p) do
    type = p["collection"] || if(String.starts_with?(operation, "media_"), do: "media", else: nil)

    if type in ~w(events initiatives campaigns newsletters articles media media_groups) and
         p["id"] do
      field = if type == "media", do: "filename", else: "title"

      case Gcf.Database.execute("SELECT #{field} AS title FROM #{type} WHERE id=?", [p["id"]]) do
        {:ok, [row]} -> Mutation.target(type, p["id"], row["title"])
        _ -> :ok
      end
    end
  end
end
