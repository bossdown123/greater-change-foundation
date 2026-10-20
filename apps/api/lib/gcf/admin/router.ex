defmodule Gcf.Admin.Router do
  use Plug.Router
  alias Gcf.Admin.Auth
  plug(Auth, :session)
  plug(:guard)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: [],
    json_decoder: Jason,
    length: 34_603_008
  )

  plug(:match)
  plug(:dispatch)

  get "/session" do
    if Auth.configured?() do
      {conn, token} = Auth.csrf(conn)
      actor = Auth.actor(conn)

      json(conn, 200, %{
        authenticated: actor != nil,
        user: if(actor, do: Gcf.Admin.Accounts.public(actor)),
        csrf: token,
        configured: true
      })
    else
      json(conn, 200, %{authenticated: false, configured: false})
    end
  end

  post "/session" do
    cond do
      not Gcf.Admin.LoginThrottle.allow?(conn.remote_ip) ->
        json(conn, 429, %{error: "Too many sign-in attempts. Try again in five minutes."})

      true ->
        case invoke("sign_in", conn.body_params, nil) do
          {:ok, %{user: user, session_version: version}} ->
            token = Auth.random()

            conn
            |> configure_session(renew: true)
            |> clear_session()
            |> put_session(:user_id, user["id"])
            |> put_session(:session_version, version)
            |> put_session(:expires, System.system_time(:second) + 28_800)
            |> put_session(:csrf, token)
            |> json(200, %{authenticated: true, user: user, csrf: token})

          _ ->
            json(conn, 401, %{error: "Email or password is incorrect."})
        end
    end
  end

  delete "/session" do
    case invoke("sign_out", %{}, conn.assigns.actor) do
      {:ok, _} -> conn |> configure_session(drop: true) |> json(200, %{authenticated: false})
      error -> respond(conn, error)
    end
  end

  get "/realtime-token" do
    json(conn, 200, %{
      token: GcfWeb.UserSocket.ticket(conn.assigns.actor, get_session(conn, :expires))
    })
  end

  get "/users" do
    action(conn, "list_users", conn.query_params)
  end

  post "/users" do
    action(conn, "save_user", %{"data" => conn.body_params})
  end

  get "/users/:id" do
    action(conn, "get_user", %{"id" => id})
  end

  put "/users/:id" do
    action(conn, "save_user", %{"id" => id, "data" => conn.body_params})
  end

  put "/password" do
    case invoke("change_password", conn.body_params, conn.assigns.actor) do
      {:ok, data} -> conn |> configure_session(drop: true) |> json(200, data)
      error -> respond(conn, error)
    end
  end

  get "/actors" do
    action(conn, "list_actors", %{})
  end

  get "/audit" do
    action(conn, "audit_list", conn.query_params)
  end

  get "/audit/:id" do
    action(conn, "audit_get", %{"id" => id})
  end

  get "/updates" do
    action(conn, "list_updates", conn.query_params)
  end

  get "/media" do
    action(conn, "media_list", conn.query_params)
  end

  post "/media" do
    action(conn, "upload", conn.body_params)
  end

  get "/media/metadata-summary" do
    action(conn, "media_summary", conn.query_params)
  end

  post "/media/:id/metadata" do
    action(conn, "media_metadata", %{"id" => id})
  end

  get "/media/:id/thumbnail" do
    send_image(conn, id, true)
  end

  get "/media/:id/file" do
    send_image(conn, id, false)
  end

  get "/media/:id" do
    action(conn, "media_get", %{"id" => id})
  end

  patch "/media/:id" do
    action(conn, "media_update", Map.put(conn.body_params, "id", id))
  end

  delete "/media/:id" do
    action(conn, "media_delete", %{"id" => id})
  end

  post "/newsletters/generate" do
    action(conn, "generate", conn.body_params)
  end

  get "/:collection" when collection in ["events", "newsletters", "initiatives", "campaigns"] do
    action(conn, "list", Map.put(conn.query_params, "collection", collection))
  end

  post "/:collection" when collection in ["events", "newsletters", "initiatives", "campaigns"] do
    action(conn, "save", %{"collection" => collection, "data" => conn.body_params})
  end

  get "/:collection/:id"
      when collection in ["events", "newsletters", "initiatives", "campaigns"] do
    action(conn, "get", %{"collection" => collection, "id" => id})
  end

  put "/:collection/:id"
      when collection in ["events", "newsletters", "initiatives", "campaigns"] do
    action(conn, "save", %{"collection" => collection, "id" => id, "data" => conn.body_params})
  end

  delete "/:collection/:id"
         when collection in ["events", "newsletters", "initiatives", "campaigns"] do
    action(conn, "delete", %{"collection" => collection, "id" => id})
  end

  match _ do
    json(conn, 404, %{error: "Not found"})
  end

  defp guard(conn, _) do
    conn = conn |> fetch_query_params() |> put_resp_header("cache-control", "no-store")
    conn = assign(conn, :actor, Auth.actor(conn))
    public_session = conn.path_info == ["session"] and conn.method in ["GET", "POST"]

    cond do
      public_session and conn.method == "GET" ->
        conn

      not Auth.configured?() ->
        json(conn, 503, %{error: "Administrator access has not been configured"}) |> halt()

      not public_session and conn.assigns.actor == nil ->
        json(conn, 401, %{error: "Please sign in"}) |> halt()

      conn.method not in ["GET", "HEAD"] and not Auth.valid_csrf?(conn) ->
        json(conn, 403, %{error: "Session expired. Sign in again."}) |> halt()

      true ->
        conn
    end
  end

  defp action(conn, operation, params) do
    respond(conn, invoke(operation, params, conn.assigns.actor))
  end

  defp invoke(operation, params, actor) do
    Gcf.Admin.Resource
    |> Ash.ActionInput.for_action(:run, %{operation: operation, params: params}, actor: actor)
    |> Ash.run_action()
  end

  defp respond(conn, {:ok, data}), do: json(conn, 200, data)

  defp respond(conn, {:error, %Ash.Error.Forbidden{}}),
    do: json(conn, 403, %{error: "Administrator access required"})

  defp respond(conn, {:error, :forbidden}),
    do: json(conn, 403, %{error: "Administrator access required"})

  defp respond(conn, {:error, :not_found}), do: json(conn, 404, %{error: "Not found"})
  defp respond(conn, {:error, error}) when is_binary(error), do: json(conn, 422, %{error: error})

  defp respond(conn, {:error, %{errors: errors}}) do
    case Enum.find_value(errors, fn
           %Ash.Error.Unknown.UnknownError{error: message} when is_binary(message) ->
             {:validation, message}

           %Ash.Error.Unknown.UnknownError{error: :forbidden} ->
             :forbidden

           %Ash.Error.Unknown.UnknownError{error: :not_found} ->
             :not_found

           _ ->
             nil
         end) do
      {:validation, message} -> json(conn, 422, %{error: message})
      :not_found -> json(conn, 404, %{error: "Not found"})
      :forbidden -> json(conn, 403, %{error: "Administrator access required"})
      _ -> json(conn, 422, %{error: "Unable to complete the request. Please try again."})
    end
  end

  defp respond(conn, {:error, _}),
    do:
      json(conn, 422, %{error: "Unable to complete the request. Check the fields and try again."})

  defp send_image(conn, id, thumbnail?) do
    case Gcf.Admin.Content.file(id, thumbnail?) do
      {:ok, bytes, mime} -> conn |> put_resp_content_type(mime) |> send_resp(200, bytes)
      _ -> json(conn, 404, %{error: "Image is unavailable"})
    end
  end

  defp json(conn, status, data),
    do:
      conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(data))
end
