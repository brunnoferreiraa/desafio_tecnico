import Config

config :w_core,
  ecto_repos: [WCore.Repo],
  generators: [timestamp_type: :utc_datetime_usec]

config :w_core, :hashing_lib, Pbkdf2

config :w_core, WCore.Repo,
  journal_mode: :wal,
  busy_timeout: 5_000

config :w_core, WCoreWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: WCoreWeb.ErrorHTML, json: WCoreWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: WCore.PubSub,
  live_view: [signing_salt: "iSCLqD5m"]

config :esbuild,
  version: "0.20.2",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
