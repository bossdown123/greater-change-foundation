import Config
config :gcf,
  port: String.to_integer(System.get_env("PORT", "4000")),
  serve: System.get_env("GCF_SERVE", "true") == "true",
  turso_url: System.get_env("TURSO_DATABASE_URL"),
  turso_token: System.get_env("TURSO_AUTH_TOKEN", "")
