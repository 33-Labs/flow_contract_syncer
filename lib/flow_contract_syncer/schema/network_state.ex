defmodule FlowContractSyncer.Schema.NetworkState do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.Network

  schema "chain_states" do
    belongs_to :network, Network
    field :synced_height, :integer
  
    timestamps()
  end

  @required_fields ~w(network_id synced_height)a
  def changeset(state, params \\ %{}) do
    state
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:network_id], name: :network_states_network_id_index)
  end

  def get_by_network_id(network_id) do
    Repo.get_by(__MODULE__, network_id: network_id) || %__MODULE__{}
  end

  def get_synced_height(%Network{id: network_id}) do
    get_synced_height(network_id)
  end

  def get_synced_height(network_id) do
    %{synced_height: synced_height} = get_by_network_id(network_id)
    synced_height
  end

  def update_height(network_id, height) do
    %{synced_height: synced_height} = model = get_by_network_id(network_id)

    model
    |> changeset(%{network_id: network_id, synced_height: height})
    |> validate_number(:synced_height, greater_than: synced_height || -1)
    |> Repo.insert_or_update()
    |> handle_update_height() 
  end

  defp handle_update_height({:error, %{errors: [synced_height: _]}}) do
    {:error, :invalid_synced_height}
  end

  defp handle_update_height(ret) do
    ret
  end
end

