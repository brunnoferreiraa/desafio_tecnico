defmodule WCoreWeb.UserResetPasswordController do
  use WCoreWeb, :controller

  alias WCore.Accounts
  alias WCore.Accounts.User

  plug :get_user_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, :new, form: Phoenix.Component.to_form(%{}, as: :user))
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    conn
    |> put_flash(
      :info,
      "Se o seu e-mail estiver no nosso sistema, você receberá em breve instruções para redefinir sua senha."
    )
    |> redirect(to: ~p"/")
  end

  def edit(conn, %{"token" => token}) do
    form =
      %User{}
      |> Accounts.change_user_password()
      |> Phoenix.Component.to_form(as: :user)

    render(conn, :edit, form: form, token: token)
  end

  def update(conn, %{"user" => user_params, "token" => token}) do
    case Accounts.reset_user_password(conn.assigns.user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Senha redefinida com sucesso.")
        |> redirect(to: ~p"/users/log_in")

      {:error, changeset} ->
        render(conn, :edit, form: Phoenix.Component.to_form(changeset, as: :user), token: token)
    end
  end

  defp get_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(conn, :user, user)
    else
      conn
      |> put_flash(:error, "O link de redefinição de senha é inválido ou expirou.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end
end
