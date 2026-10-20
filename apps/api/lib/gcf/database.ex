defmodule Gcf.Database do
  @moduledoc "Small Turso HTTP boundary; credentials never reach the browser."
  def ready do
    case Application.get_env(:gcf, :turso_url) do
      url when is_binary(url) and url != "" -> query(url)
      _ -> {:error, "Database is not configured"}
    end
  end

  defp query(url) do
    url = String.replace_prefix(url, "libsql://", "https://")
    token = Application.get_env(:gcf, :turso_token, "")
    headers = if token == "", do: [], else: [{"authorization", "Bearer " <> token}]

    body = %{
      requests: [
        %{type: "execute", stmt: %{sql: "SELECT version FROM gcf_schema WHERE id = 1"}},
        %{type: "close"}
      ]
    }

    case Req.post(url <> "/v2/pipeline",
           headers: headers,
           json: body,
           connect_options: [timeout: 3000],
           receive_timeout: 3000,
           retry: false
         ) do
      {:ok,
       %{
         status: 200,
         body: %{
           "results" => [
             %{
               "type" => "ok",
               "response" => %{"result" => %{"rows" => [[%{"value" => version}]]}}
             }
             | _
           ]
         }
       }}
      when version == "5" ->
        {:ok, %{status: "ready", database: "turso", schema_version: 5}}

      _ ->
        {:error, "Database is unavailable or migrations are pending"}
    end
  end

  def execute(sql, args \\ []) do
    with {:ok, [result]} <- batch([{sql, args}]) do
      {:ok, result}
    end
  end

  def batch(statements, opts \\ []) do
    with {:ok, framed, prefix, suffix} <- Gcf.Admin.Mutation.frame(statements, opts),
         {:ok, results} <- perform(framed) do
      {:ok, results |> Enum.drop(prefix) |> Enum.take(length(results) - prefix - suffix)}
    end
  end

  defp perform(statements) do
    url = Application.get_env(:gcf, :turso_url, "") || ""
    token = Application.get_env(:gcf, :turso_token, "")
    headers = if token == "", do: [], else: [{"authorization", "Bearer " <> token}]

    steps =
      Enum.map(statements, fn {sql, args} ->
        %{stmt: %{sql: sql, args: Enum.map(args, &value/1)}, condition: nil}
      end)

    # A single Hrana batch shares a transaction and checks every statement.
    steps =
      ([%{stmt: %{sql: "BEGIN IMMEDIATE"}}] ++
         Enum.with_index(steps, 1))
      |> Enum.map(fn
        {%{stmt: stmt}, i} -> %{stmt: stmt, condition: %{type: "ok", step: i - 1}}
        step -> step
      end)

    steps =
      steps ++ [%{stmt: %{sql: "COMMIT"}, condition: %{type: "ok", step: length(steps) - 1}}]

    body = %{
      requests: [
        %{type: "execute", stmt: %{sql: "PRAGMA foreign_keys=ON"}},
        %{type: "batch", batch: %{steps: steps}},
        %{type: "close"}
      ]
    }

    with true <- url != "",
         {:ok,
          %{
            status: 200,
            body: %{"results" => [_, %{"type" => "ok", "response" => %{"result" => result}} | _]}
          }} <-
           Req.post(String.replace_prefix(url, "libsql://", "https://") <> "/v2/pipeline",
             headers: headers,
             json: body,
             receive_timeout: 15_000,
             retry: false
           ),
         true <- Enum.all?(result["step_errors"], &is_nil/1),
         results when is_list(results) <- result["step_results"] do
      {:ok, results |> Enum.drop(1) |> Enum.drop(-1) |> Enum.map(&decode/1)}
    else
      _ -> {:error, :database_unavailable}
    end
  end

  defp value(nil), do: %{type: "null"}
  defp value(n) when is_integer(n), do: %{type: "integer", value: Integer.to_string(n)}
  defp value(n) when is_float(n), do: %{type: "float", value: n}
  defp value(s), do: %{type: "text", value: to_string(s)}

  defp decode(result) do
    names = Enum.map(result["cols"], & &1["name"])

    Enum.map(result["rows"], fn row ->
      Map.new(
        Enum.zip(
          names,
          Enum.map(row, fn
            %{"type" => "null"} -> nil
            %{"type" => "integer", "value" => n} -> String.to_integer(n)
            %{"value" => v} -> v
          end)
        )
      )
    end)
  end
end
