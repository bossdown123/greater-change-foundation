defmodule Gcf.Router do
  use Plug.Router
  plug(:security_headers)
  plug(Plug.Static, at: "/", from: {:gcf, "priv/static"}, only: ~w(assets favicon.svg))
  plug(:match)
  plug(:dispatch)

  get "/healthz" do
    json(conn, 200, %{status: "ok"})
  end

  get "/readyz" do
    case Ash.ActionInput.for_action(Gcf.Foundation.Status, :readiness, %{}) |> Ash.run_action() do
      {:ok, result} -> json(conn, 200, result)
      {:error, _} -> json(conn, 503, %{status: "unavailable"})
    end
  end

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:gcf, "priv/static/index.html"))
  end

  match _ do
    json(conn, 404, %{error: "not_found"})
  end

  defp json(conn, status, data) do
    conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(data))
  end

  defp security_headers(conn, _) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
    )
  end
end
