defmodule Gcf.Admin.Auth do
  import Plug.Conn
  def init(opts), do: opts
  def call(conn, :session), do: session(conn, [])

  def session(conn, _) do
    secret = Application.get_env(:gcf, :session_secret, "")
    # Fail closed when the deployment has not supplied a real signing secret.
    if byte_size(secret) >= 64 do
      opts =
        Plug.Session.init(
          store: :cookie,
          key: "_gcf_admin",
          signing_salt: "gcf-admin-v1",
          encryption_salt: "gcf-private-v1",
          same_site: "Strict",
          http_only: true,
          secure: Application.get_env(:gcf, :cookie_secure, true),
          max_age: 28_800
        )

      %{conn | secret_key_base: secret} |> Plug.Session.call(opts) |> fetch_session()
    else
      conn |> put_private(:plug_session, %{}) |> put_private(:plug_session_fetch, :done)
    end
  end

  def csrf(conn) do
    case get_session(conn, :csrf) do
      nil ->
        token = random()
        {put_session(conn, :csrf, token), token}

      token ->
        {conn, token}
    end
  end

  def configured? do
    byte_size(Application.get_env(:gcf, :session_secret, "")) >= 64
  end

  def actor(conn) do
    if configured?() and (get_session(conn, :expires) || 0) > System.system_time(:second) do
      Gcf.Admin.Accounts.session_actor(
        get_session(conn, :user_id),
        get_session(conn, :session_version)
      )
    end
  end

  def authenticated?(conn), do: actor(conn) != nil

  def valid_csrf?(conn) do
    expected = get_session(conn, :csrf)

    case get_req_header(conn, "x-csrf-token") do
      [actual] when is_binary(expected) and byte_size(actual) == byte_size(expected) ->
        Plug.Crypto.secure_compare(actual, expected)

      _ ->
        false
    end
  end

  def hash_password(password) do
    salt = :crypto.strong_rand_bytes(16)
    hash = :crypto.pbkdf2_hmac(:sha256, password, salt, 600_000, 32)
    "pbkdf2:" <> Base.encode16(salt, case: :lower) <> ":" <> Base.encode16(hash, case: :lower)
  end

  def verify_hash(password, encoded)
      when is_binary(password) and byte_size(password) <= 1024 and is_binary(encoded) do
    case String.split(encoded, ":") do
      ["pbkdf2", salt, hash] ->
        with {:ok, salt} <- Base.decode16(salt, case: :mixed),
             {:ok, expected} <- Base.decode16(hash, case: :mixed),
             true <- byte_size(expected) == 32 do
          actual = :crypto.pbkdf2_hmac(:sha256, password, salt, 600_000, 32)
          Plug.Crypto.secure_compare(actual, expected)
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  def verify_hash(_, _), do: false
  def random, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
end

defmodule Gcf.Admin.LoginThrottle do
  use GenServer
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(state), do: {:ok, state}
  def allow?(ip), do: GenServer.call(__MODULE__, {:attempt, ip})

  def handle_call({:attempt, ip}, _from, state) do
    now = System.monotonic_time(:second)
    state = Map.reject(state, fn {_, {time, _}} -> now - time > 300 end)
    {time, count} = Map.get(state, ip, {now, 0})

    if count >= 10 do
      {:reply, false, state}
    else
      {:reply, true, Map.put(state, ip, {time, count + 1})}
    end
  end
end
