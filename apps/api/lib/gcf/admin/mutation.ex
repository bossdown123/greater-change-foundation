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
      occurred_at: DateTime.to_iso8601(DateTime.utc_now())
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
          prefix = [
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
            {"INSERT INTO audit_context(singleton,action_id) VALUES(1,?)", [c.id]}
          ]

          {:ok, prefix ++ statements ++ [{"DELETE FROM audit_context WHERE singleton=1", []}], 2,
           1}
      end
    else
      {:ok, statements, 0, 0}
    end
  end
end
