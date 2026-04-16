defmodule WCoreWeb.UserSettingsController do
  use WCoreWeb, :controller

  alias WCore.Accounts
  alias WCoreWeb.UserAuth

  plug :assign_email_and_password_forms

  def edit(conn, _params) do
    render(conn, :edit,
      email_form: conn.assigns.email_form,
      password_form: conn.assigns.password_form
    )
  end

  def update(conn, %{"action" => "update_email", "user" => user_params}) do
    user = conn.assigns.current_user
    password = current_password_from_params(conn.params, user_params)

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        render(conn, :edit,
          email_form: Phoenix.Component.to_form(changeset, as: :user),
          password_form: conn.assigns.password_form
        )
    end
  end

  def update(conn, %{"action" => "update_password", "user" => user_params}) do
    user = conn.assigns.current_user
    current_password = current_password_from_params(conn.params, user_params)

    case Accounts.update_user_password(user, current_password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit,
          email_form: conn.assigns.email_form,
          password_form: Phoenix.Component.to_form(changeset, as: :user)
        )
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  defp assign_email_and_password_forms(conn, _opts) do
    user = conn.assigns.current_user

    email_form =
      user
      |> Accounts.change_user_email()
      |> Phoenix.Component.to_form(as: :user)

    password_form =
      user
      |> Accounts.change_user_password()
      |> Phoenix.Component.to_form(as: :user)

    conn
    |> assign(:email_form, email_form)
    |> assign(:password_form, password_form)
  end

  defp current_password_from_params(params, user_params) do
    params["current_password"] || user_params["current_password"]
  end
end
