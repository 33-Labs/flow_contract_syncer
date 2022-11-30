defmodule FlowContractSyncer.Schema.Dependency do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "dependencies" do
    field :contract_id, :id
    field :dependency_id, :id

    timestamps()
  end

  @required_fields ~w(contract_id dependency_id)a
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @attrs)
    |> unique_constraint(
      [:contract_id, :dependency_id],
      name: :dependencies_contract_id_dependency_id_index
    )
    |> unique_constraint(
      [:dependency_id, :contract_id],
      name: :dependencies_dependency_id_contract_id_index
    )
  end
end