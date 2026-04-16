defmodule WCore.DataCase do
  @moduledoc """
  Setup for tests that need access to the data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias WCore.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import WCore.DataCase
    end
  end

  setup tags do
    WCore.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(WCore.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
