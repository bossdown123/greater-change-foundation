import Config

config :gcf,
  port: String.to_integer(System.get_env("PORT", "4000")),
  serve: System.get_env("GCF_SERVE", "true") == "true",
  turso_url: System.get_env("TURSO_DATABASE_URL"),
  turso_token: System.get_env("TURSO_AUTH_TOKEN", "")

config :gcf,
  session_secret: System.get_env("GCF_SESSION_SECRET", ""),
  admin_email: System.get_env("GCF_ADMIN_EMAIL", ""),
  admin_password_hash: System.get_env("GCF_ADMIN_PASSWORD_HASH", ""),
  cookie_secure: System.get_env("GCF_COOKIE_SECURE", "true") == "true",
  storage: [
    endpoint: System.get_env("S3_ENDPOINT", ""),
    bucket: System.get_env("S3_BUCKET", "gcf-media"),
    region: System.get_env("S3_REGION", "garage"),
    access_key_id: System.get_env("S3_ACCESS_KEY_ID", ""),
    secret_access_key: System.get_env("S3_SECRET_ACCESS_KEY", "")
  ]

config :gcf, GcfWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
  server: System.get_env("GCF_SERVE", "true") == "true",
  secret_key_base: System.get_env("GCF_SESSION_SECRET", ""),
  pubsub_server: Gcf.PubSub,
  check_origin: [
    "//greaterchangefoundation.org",
    "//www.greaterchangefoundation.org",
    "//localhost",
    "//127.0.0.1"
  ]

config :phoenix, :json_library, Jason
config :phoenix, :filter_parameters, ["password", "token", "csrf", "current_password"]
