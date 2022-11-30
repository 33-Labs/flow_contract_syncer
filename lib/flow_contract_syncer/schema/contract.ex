defmodule FlowContractSyncer.Schema.Contract do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.{Dependency, Network}

  schema "contracts" do
    belongs_to :network, Network
    many_to_many :dependencies,
      __MODULE__,
      join_through: Dependency,
      join_keys: [contract_id: :id, dependency_id: :id]

    many_to_many :dependants,
      __MODULE__,
      join_through: Dependency,
      join_keys: [dependency_id: :id, contract_id: :id]

    field :uuid, :string
    field :address, :string
    field :name, :string
    field :status, Ecto.Enum, values: [normal: 0, removed: 1]
    field :code, :string
  
    timestamps()
  end

  @required_fields ~w(network_id uuid address name status code)a
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:network_id, :uuid], name: :contracts_network_id_uuid_index)
  end
end