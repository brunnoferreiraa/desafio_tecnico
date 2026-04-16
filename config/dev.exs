import Config

config :w_core, WCore.Repo,
  database: Path.expand("../w_core_dev.db", __DIR__),
  pool_size: 10,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :w_core, WCoreWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "GxjoMpvUSn0uP08DktNxwotKW4OXdq5Ls6hMwlhGW3kKctGd12uTQRP8JqxcPzgu",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]

config :w_core, WCoreWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/w_core_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
