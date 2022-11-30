defmodule FlowContractSyncer.Schema.Network do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "networks" do
    field :name, :string
    field :endpoint, :string
    field :min_sync_height, :integer
  end

  @required_fields ~w(name endpoint min_sync_height)a
  def changeset(network, params \\ %{}) do
    network
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:name], name: :networks_name_index)
  end
end