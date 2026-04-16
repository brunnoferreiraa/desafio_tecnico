defmodule WCoreWeb.UserConfirmationController do
  use WCoreWeb, :controller

  alias WCore.Accounts

  def new(conn, _params) do
    render(conn, :new, form: Phoenix.Component.to_form(%{}, as: :user))
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."
    )
    |> redirect(to: ~p"/")
  end

  def edit(conn, %{"token" => token}) do
    render(conn, :edit, token: token)
  end

  def update(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User confirmed successfully.")
        |> redirect(to: ~p"/")

      :error ->
        if conn.assigns[:current_user] do
          redirect(conn, to: ~p"/")
        else
          conn
          |> put_flash(:error, "User confirmation link is invalid or it has expired.")
          |> redirect(to: ~p"/")
        end
    end
  end
end
