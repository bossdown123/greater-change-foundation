defmodule Gcf.Router do
  use Plug.Router
  plug(Plug.Head)
  plug(:security_headers)

  plug(Plug.Static,
    at: "/",
    from: {:gcf, "priv/static"},
    only: ~w(assets favicon.svg robots.txt sitemap.xml)
  )

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

  forward("/api/admin", to: Gcf.Admin.Router)

  get "/admin" do
    conn
    |> put_resp_content_type("text/html")
    |> put_resp_header("cache-control", "no-store")
    |> send_file(200, Application.app_dir(:gcf, "priv/static/admin.html"))
  end

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:gcf, "priv/static/index.html"))
  end

  get "/:page" when page in ~w(our-work updates about support privacy) do
    public_page(conn, page)
  end

  get "/our-work/:slug"
      when slug in ~w(childs-month-2025 blood-drive-2024 christmas-2023 anniversary-celebration christmas-2022) do
    public_page(conn, "our-work--" <> slug)
  end

  defp public_page(conn, page) do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:gcf, "priv/static/pages/" <> page <> ".html"))
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
      "default-src 'self'; script-src 'self'; style-src 'self'; style-src-attr 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self' wss://greaterchangefoundation.org wss://www.greaterchangefoundation.org ws://127.0.0.1:4000 ws://127.0.0.1:4173 ws://localhost:4000 ws://localhost:4173; form-action 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
    )
  end
end
