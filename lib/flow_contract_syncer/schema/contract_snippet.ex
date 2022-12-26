defmodule FlowContractSyncer.Schema.ContractSnippet do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "contract_snippets" do
    field :contract_id, :id
    field :snippet_id, :id

    timestamps()
  end

  @required_fields ~w(contract_id snippet_id)a
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_fields)
    |> unique_constraint(
      [:contract_id, :snippet_id],
      name: :contract_snippets_contract_id_snippet_id_index
    )
    |> unique_constraint(
      [:snippet_id, :contract_id],
      name: :contract_snippets_snippet_id_contract_id_index
    )
  end
end
