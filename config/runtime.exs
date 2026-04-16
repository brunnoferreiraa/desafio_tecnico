import Config

if config_env() == :prod do
  database_path = System.get_env("DATABASE_PATH") || "/var/lib/w_core/w_core_prod.db"
  pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :w_core, WCore.Repo,
    database: database_path,
    pool_size: pool_size,
    journal_mode: :wal,
    busy_timeout: 10_000

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      Generate one with: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :w_core, WCoreWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    server: true
end
