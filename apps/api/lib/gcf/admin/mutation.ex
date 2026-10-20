defmodule Gcf.Admin.Mutation do
  @moduledoc "Ash mutation context, committed with row-level audit records in the same transaction."
  @key {__MODULE__, :context}

  def run(actor, operation, params, fun) do
    previous = Process.get(@key)

    type =
      params["collection"] ||
        if(String.starts_with?(operation, "media_"), do: "media", else: operation)

    context = %{
      id: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower),
      actor_id: actor["id"],
      operation: verb(operation, params),
      resource_type: type,
      resource_id: params["id"],
      resource_title: get_in(params, ["data", "title"]) || "",
      occurred_at: DateTime.to_iso8601(DateTime.utc_now()),
      create_only: operation == "create_draft",
      expected:
        if(operation == "save",
          do: get_in(params, ["data", "updated_at"]),
          else: if(operation == "media_update", do: params["updated_at"])
        )
    }

    Process.put(@key, context)

    try do
      fun.()
    after
      if previous, do: Process.put(@key, previous), else: Process.delete(@key)
    end
  end

  defp verb("save", p), do: if(p["id"], do: "update", else: "create")
  defp verb("save_user", p), do: if(p["id"], do: "update_user", else: "create_user")
  defp verb("media_update", _), do: "update"
  defp verb("media_delete", _), do: "delete"
  defp verb(op, _), do: op

  def target(type, id, title \\ "") do
    if context = Process.get(@key) do
      Process.put(@key, %{
        context
        | resource_type: type,
          resource_id: id,
          resource_title: title || ""
      })
    end

    :ok
  end

  def committed do
    if context = Process.get(@key) do
      if Process.whereis(Gcf.PubSub) do
        Phoenix.PubSub.broadcast(
          Gcf.PubSub,
          "admin:changes",
          {:changed,
           Map.take(context, [:id, :actor_id, :operation, :resource_type, :resource_id])}
        )
      end
    end

    :ok
  end

  def activity do
    case Gcf.Database.batch([{"SELECT 1", []}], audit: true) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def frame(statements, opts) do
    writes =
      Keyword.get(opts, :audit, false) or
        Enum.any?(statements, fn {sql, _} ->
          Regex.match?(~r/^\s*(INSERT|UPDATE|DELETE|REPLACE)\b/i, sql)
        end)

    if writes do
      case Process.get(@key) do
        nil ->
          {:error, :audit_context_required}

        c ->
          context_statement =
            cond do
              c.create_only and c.resource_type in ~w(events initiatives campaigns newsletters) ->
                {"INSERT INTO audit_context(singleton,action_id) SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM #{c.resource_type} WHERE id=?) THEN 1 ELSE 0 END,?",
                 [c.resource_id, c.id]}

              c.expected && c.resource_id &&
                  c.resource_type in ~w(events initiatives campaigns newsletters media) ->
                {"INSERT INTO audit_context(singleton,action_id) SELECT CASE WHEN EXISTS(SELECT 1 FROM #{c.resource_type} WHERE id=? AND updated_at=?) THEN 1 ELSE 0 END,?",
                 [c.resource_id, c.expected, c.id]}

              true ->
                {"INSERT INTO audit_context(singleton,action_id) VALUES(1,?)", [c.id]}
            end

          prefix =
            [
              {"INSERT INTO audit_actions(id,actor_id,operation,resource_type,resource_id,resource_title,occurred_at) VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO NOTHING",
               [
                 c.id,
                 c.actor_id,
                 c.operation,
                 c.resource_type,
                 c.resource_id,
                 c.resource_title,
                 c.occurred_at
               ]},
              context_statement
            ]

          {:ok, prefix ++ statements ++ [{"DELETE FROM audit_context WHERE singleton=1", []}],
           length(prefix), 1}
      end
    else
      {:ok, statements, 0, 0}
    end
  end
end
