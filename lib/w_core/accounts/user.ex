defmodule WCore.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @hashing_lib Application.compile_env(:w_core, :hashing_lib, Pbkdf2)

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> validate_email_changed()
  end

  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  def confirm_changeset(user) do
    now =
      DateTime.utc_now()
      |> DateTime.to_unix(:microsecond)
      |> DateTime.from_unix!(:microsecond)

    change(user, confirmed_at: now)
  end

  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, WCore.Repo)
      |> validate_email_case_insensitive_uniqueness()
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_change(changeset, :email) do
      changeset
    else
      add_error(changeset, :email, "did not change")
    end
  end

  defp validate_email_case_insensitive_uniqueness(changeset) do
    email = get_field(changeset, :email)
    user_id = changeset.data.id

    cond do
      is_nil(email) ->
        changeset

      Keyword.has_key?(changeset.errors, :email) ->
        changeset

      email_exists?(email, user_id) ->
        add_error(changeset, :email, "has already been taken")

      true ->
        changeset
    end
  end

  defp email_exists?(email, user_id) do
    base_query =
      from user in __MODULE__,
        where: fragment("lower(?) = lower(?)", user.email, ^email)

    query =
      if is_nil(user_id) do
        base_query
      else
        from user in base_query, where: user.id != ^user_id
      end

    WCore.Repo.exists?(query)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && is_binary(password) && changeset.valid? do
      changeset
      |> put_change(:hashed_password, @hashing_lib.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    @hashing_lib.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    @hashing_lib.no_user_verify()
    false
  end
end
