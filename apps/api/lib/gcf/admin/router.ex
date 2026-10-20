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
      json(conn, 200, %{authenticated: Auth.authenticated?(conn), csrf: token, configured: true})
    else
      json(conn, 200, %{authenticated: false, configured: false})
    end
  end

  post "/session" do
    cond do
      not Gcf.Admin.LoginThrottle.allow?(conn.remote_ip) ->
        json(conn, 429, %{error: "Too many sign-in attempts. Try again in five minutes."})

      Auth.verify(conn.body_params["password"]) ->
        token = Auth.random()

        conn
        |> configure_session(renew: true)
        |> clear_session()
        |> put_session(:admin, true)
        |> put_session(:expires, System.system_time(:second) + 28_800)
        |> put_session(:csrf, token)
        |> json(200, %{authenticated: true, csrf: token})

      true ->
        json(conn, 401, %{error: "The password is incorrect."})
    end
  end

  delete "/session" do
    conn |> configure_session(drop: true) |> json(200, %{authenticated: false})
  end

  get "/updates" do
    action(conn, "list_updates", conn.query_params)
  end

  get "/media" do
    action(conn, "media_list", conn.query_params)
  end

  post "/media" do
    respond(conn, Gcf.Admin.Content.upload(conn.body_params["file"], conn.body_params))
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
    public_session = conn.path_info == ["session"] and conn.method in ["GET", "POST"]

    cond do
      public_session and conn.method == "GET" ->
        conn

      not Auth.configured?() ->
        json(conn, 503, %{error: "Administrator access has not been configured"}) |> halt()

      not public_session and not Auth.authenticated?(conn) ->
        json(conn, 401, %{error: "Please sign in"}) |> halt()

      conn.method not in ["GET", "HEAD"] and not Auth.valid_csrf?(conn) ->
        json(conn, 403, %{error: "Session expired. Reload and try again."}) |> halt()

      true ->
        conn
    end
  end

  defp action(conn, operation, params) do
    result =
      Gcf.Admin.Resource
      |> Ash.ActionInput.for_action(:run, %{operation: operation, params: params},
        actor: :gcf_admin
      )
      |> Ash.run_action()

    respond(conn, result)
  end

  defp respond(conn, {:ok, data}), do: json(conn, 200, data)
  defp respond(conn, {:error, :not_found}), do: json(conn, 404, %{error: "Not found"})
  defp respond(conn, {:error, error}) when is_binary(error), do: json(conn, 422, %{error: error})

  defp respond(conn, {:error, %{errors: errors}}) do
    case Enum.find_value(errors, fn
           %Ash.Error.Unknown.UnknownError{error: message} when is_binary(message) ->
             {:validation, message}

           %Ash.Error.Unknown.UnknownError{error: :not_found} ->
             :not_found

           _ ->
             nil
         end) do
      {:validation, message} -> json(conn, 422, %{error: message})
      :not_found -> json(conn, 404, %{error: "Not found"})
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
