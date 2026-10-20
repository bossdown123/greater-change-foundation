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
             %{"type" => "ok", "response" => %{"result" => %{"rows" => [[%{"value" => "1"}]]}}}
             | _
           ]
         }
       }} ->
        {:ok, %{status: "ready", database: "turso", schema_version: 1}}

      _ ->
        {:error, "Database is unavailable or migrations are pending"}
    end
  end
end
