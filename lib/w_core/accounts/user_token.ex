defmodule WCore.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query

  alias WCore.Accounts.UserToken

  @hash_algorithm :sha256
  @rand_size 32

  @session_validity_in_days 60
  @reset_password_validity_in_days 1
  @confirm_validity_in_days 7
  @change_email_validity_in_days 7

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, WCore.Accounts.User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %UserToken{token: token, context: "session", user_id: user.id}}
  end

  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(^@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  def verify_email_token_query(token, context) do
    with {:ok, decoded_token} <- Base.url_decode64(token, padding: false) do
      hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
      days = token_validity_in_days_for_context(context)

      query =
        from token in by_token_and_context_query(hashed_token, context),
          join: user in assoc(token, :user),
          where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
          select: user

      {:ok, query}
    else
      :error -> :error
    end
  end

  def verify_change_email_token_query(token, "change:" <> _current_email = context) do
    with {:ok, decoded_token} <- Base.url_decode64(token, padding: false) do
      hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

      query =
        from token in by_token_and_context_query(hashed_token, context),
          where: token.inserted_at > ago(^@change_email_validity_in_days, "day")

      {:ok, query}
    else
      :error -> :error
    end
  end

  def verify_change_email_token_query(_, _), do: :error

  def by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  def by_user_and_contexts_query(user, :all) do
    from t in UserToken, where: t.user_id == ^user.id
  end

  def by_user_and_contexts_query(user, [_ | _] = contexts) do
    from t in UserToken, where: t.user_id == ^user.id and t.context in ^contexts
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {
      Base.url_encode64(token, padding: false),
      %UserToken{
        token: hashed_token,
        context: context,
        sent_to: sent_to,
        user_id: user.id
      }
    }
  end

  defp token_validity_in_days_for_context("confirm"), do: @confirm_validity_in_days
  defp token_validity_in_days_for_context("reset_password"), do: @reset_password_validity_in_days
  defp token_validity_in_days_for_context(_), do: @reset_password_validity_in_days
end
