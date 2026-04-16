defmodule WCore.Accounts.UserNotifier do
  @moduledoc """
  Delivers account emails.
  """

  require Logger

  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  defp deliver(to, subject, body) do
    Logger.info("""
    [UserNotifier] To: #{to}
    [UserNotifier] Subject: #{subject}
    [UserNotifier] Body:
    #{body}
    """)

    {:ok, %{to: to, subject: subject, text_body: body}}
  end
end
