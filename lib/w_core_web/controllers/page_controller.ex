defmodule WCoreWeb.PageController do
  use WCoreWeb, :controller

  def home(conn, _params) do
    if conn.assigns.current_user do
      redirect(conn, to: ~p"/dashboard")
    else
      redirect(conn, to: ~p"/users/log_in")
    end
  end

  def favicon(conn, _params) do
    send_resp(conn, :no_content, "")
  end
end
