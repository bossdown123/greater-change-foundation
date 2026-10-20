defmodule Gcf.Admin.Accounts do
  alias Gcf.Database, as: DB
  alias Gcf.Admin.Mutation

  @public "id,email,name,role,active,created_at,updated_at,(SELECT color FROM user_colors WHERE user_id=users.id) AS color"

  def bootstrap do
    email = Application.get_env(:gcf, :admin_email, "") |> String.trim() |> String.downcase()
    hash = Application.get_env(:gcf, :admin_password_hash, "")

    with true <- valid_email?(email) and hash != "",
         {:ok, [%{"count" => 0}]} <- DB.execute("SELECT COUNT(*) AS count FROM users") do
      Mutation.run(%{"id" => "bootstrap"}, "account_setup", %{}, fn ->
        id = id()
        Mutation.target("users", id, email)
        now = now()

        DB.batch([
          {"INSERT INTO actors(id,kind,label,created_at) SELECT ?,'user','',? WHERE NOT EXISTS(SELECT 1 FROM users)",
           [id, now]},
          {"INSERT INTO users(id,email,name,password_hash,role,active,session_version,created_at,updated_at) SELECT ?,?, 'Administrator',?,'administrator',1,1,?,? WHERE NOT EXISTS(SELECT 1 FROM users)",
           [id, email, hash, now, now]},
          {"INSERT INTO user_colors(user_id,color) SELECT ?,? WHERE EXISTS(SELECT 1 FROM users WHERE id=?)",
           [id, color(id), id]}
        ])
      end)
    else
      {:ok, _} -> :ok
      false -> :ok
      error -> error
    end
  end

  def authenticate(email, password) do
    email = if is_binary(email), do: String.downcase(String.trim(email)), else: ""

    result =
      DB.execute(
        "SELECT *, (SELECT color FROM user_colors WHERE user_id=users.id) AS color FROM users WHERE email=? COLLATE NOCASE AND active=1",
        [email]
      )

    row =
      case result do
        {:ok, [row]} -> row
        _ -> nil
      end

    hash =
      if row,
        do: row["password_hash"],
        else: "pbkdf2:00000000000000000000000000000000:" <> String.duplicate("0", 64)

    if Gcf.Admin.Auth.verify_hash(password, hash) and row,
      do: {:ok, row},
      else: {:error, "Email or password is incorrect."}
  end

  def session_actor(id, version) when is_binary(id) and is_integer(version) do
    case DB.execute(
           "SELECT #{@public},session_version FROM users WHERE id=? AND active=1 AND session_version=?",
           [id, version]
         ) do
      {:ok, [row]} -> row
      _ -> nil
    end
  end

  def session_actor(_, _), do: nil

  def public(user), do: Map.take(user, ~w(id email name role active created_at updated_at color))

  def run("list_users", p, _actor) do
    Gcf.Admin.Page.fetch(
      "SELECT #{@public} FROM users WHERE email LIKE ? OR name LIKE ?",
      [query(p), query(p)],
      "name,id",
      page(p),
      24
    )
  end

  def run("get_user", p, _actor), do: get(p["id"])

  def run("save_user", p, actor) do
    d = p["data"] || %{}
    email = String.downcase(String.trim(to_string(d["email"] || "")))
    name = String.trim(to_string(d["name"] || ""))
    role = d["role"] || "editor"
    active = if d["active"] == false or d["active"] == 0, do: 0, else: 1
    password = d["password"]

    with true <-
           valid_email?(email) and byte_size(name) in 1..120 and
             role in ["administrator", "editor"],
         true <- p["id"] != nil or valid_password?(password),
         true <- password in [nil, ""] or valid_password?(password),
         {:ok, existing} <- existing(p["id"]) do
      id = p["id"] || id()
      Mutation.target("users", id, name)
      now = now()

      statements =
        if existing do
          # Revokes every existing session after a role, status or credential change.
          changed_auth =
            existing["role"] != role or existing["active"] != active or password not in [nil, ""] or
              existing["email"] != email

          hash =
            if password in [nil, ""],
              do: existing["password_hash"],
              else: Gcf.Admin.Auth.hash_password(password)

          [
            {"UPDATE users SET email=?,name=?,role=?,active=?,password_hash=?,session_version=session_version+?,updated_at=? WHERE id=?",
             [email, name, role, active, hash, if(changed_auth, do: 1, else: 0), now, id]}
          ]
        else
          [
            {"INSERT INTO actors VALUES(?,'user','',?)", [id, now]},
            {"INSERT INTO users(id,email,name,password_hash,role,active,session_version,created_at,updated_at) VALUES(?,?,?,?,?,?,1,?,?)",
             [id, email, name, Gcf.Admin.Auth.hash_password(password), role, active, now, now]},
            {"INSERT INTO user_colors(user_id,color) VALUES(?,?)", [id, color(id)]}
          ]
        end

      if id == actor["id"] and (active == 0 or role != "administrator"),
        do: {:error, "You cannot remove your own administrator access."},
        else: save(statements, id)
    else
      false -> {:error, "Use a valid email, name, role and a password of at least 10 characters."}
      error -> error
    end
  end

  def run("change_password", p, actor) do
    with {:ok, row} <- existing(actor["id"]),
         true <- Gcf.Admin.Auth.verify_hash(p["current_password"], row["password_hash"]),
         true <- valid_password?(p["password"]) do
      Mutation.target("users", actor["id"], actor["name"])

      with {:ok, _} <-
             DB.execute(
               "UPDATE users SET password_hash=?,session_version=session_version+1,updated_at=? WHERE id=?",
               [Gcf.Admin.Auth.hash_password(p["password"]), now(), actor["id"]]
             ),
           do: {:ok, %{changed: true}}
    else
      false ->
        {:error,
         "Check your current password and use at least 10 characters for the new password."}

      error ->
        error
    end
  end

  defp save(statements, id) do
    with {:ok, _} <- DB.batch(statements), do: get(id)
  end

  defp get(id) do
    case DB.execute("SELECT #{@public} FROM users WHERE id=?", [id]) do
      {:ok, [row]} -> {:ok, row}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  defp existing(nil), do: {:ok, nil}

  defp existing(id) do
    case DB.execute("SELECT * FROM users WHERE id=?", [id]) do
      {:ok, [row]} -> {:ok, row}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  defp color(id) do
    Enum.at(
      ["#2563eb", "#a855f7", "#db2777", "#d97706", "#059669", "#0891b2", "#e11d48", "#4f46e5"],
      :erlang.phash2(id, 8)
    )
  end

  defp valid_email?(email),
    do: byte_size(email) <= 254 and Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email)

  defp valid_password?(p), do: is_binary(p) and byte_size(p) in 10..1024
  defp id, do: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  defp now, do: DateTime.to_iso8601(DateTime.utc_now())

  defp page(p) do
    case Integer.parse(to_string(p["page"] || "1")) do
      {n, ""} when n > 0 -> min(n, 100_000)
      _ -> 1
    end
  end

  defp query(p), do: "%" <> String.slice(to_string(p["query"] || ""), 0, 200) <> "%"
end
