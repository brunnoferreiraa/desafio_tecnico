defmodule WCoreWeb.UserSessionController do
  use WCoreWeb, :controller

  alias WCore.Accounts
  alias WCoreWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, form: Phoenix.Component.to_form(%{}, as: "user"), error_message: nil)
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}} = params) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, params)
    else
      render(conn, :new,
        form: Phoenix.Component.to_form(%{"email" => email}, as: "user"),
        error_message: "Invalid email or password."
      )
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
