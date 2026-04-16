import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :pbkdf2_elixir, :rounds, 1

config :w_core, WCore.Repo,
  database: Path.expand("../w_core_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

config :w_core, WCoreWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "NNY4mKbqIOq7nFfD1I9kpxb66eo7jAhi5U6S3DB3sHw5Q4uBnywaXqgqYj3Qa5vR",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
