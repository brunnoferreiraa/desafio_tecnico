defmodule WCoreWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :w_core

  @session_options [
    store: :cookie,
    key: "_w_core_key",
    signing_salt: "cz7WfNNu",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
  end

  plug Plug.Static,
    at: "/",
    from: :w_core,
    gzip: false,
    only: WCoreWeb.static_paths()

  if code_reloading? do
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :w_core
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug WCoreWeb.Router
end
