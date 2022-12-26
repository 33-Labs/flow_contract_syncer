defmodule FlowContractSyncer.Schema.NetworkState do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.Network

  schema "network_states" do
    belongs_to :network, Network
    field :synced_height, :integer
    field :contract_search_count, :integer
    field :snippet_search_count, :integer

    timestamps()
  end

  @required_fields ~w(network_id synced_height contract_search_count snippet_search_count)a
  def changeset(state, params \\ %{}) do
    state
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:network_id], name: :network_states_network_id_index)
  end

  def inc_contract_search_count(%__MODULE__{id: network_id}) do
    Repo.transaction(fn ->
      state =
        __MODULE__
        |> where(network_id: ^network_id)
        |> Repo.one()

      state
      |> changeset(%{contract_search_count: state.contract_search_count + 1})
      |> Repo.update!()
    end)
  end

  def inc_snippet_search_count(%__MODULE__{id: network_id}) do
    Repo.transaction(fn ->
      state =
        __MODULE__
        |> where(network_id: ^network_id)
        |> Repo.one()

      state
      |> changeset(%{snippet_search_count: state.snippet_search_count + 1})
      |> Repo.update!()
    end)
  end

  def get_by_network_id(network_id) do
    case Repo.get_by(__MODULE__, network_id: network_id) do
      nil ->
        %__MODULE__{} |> changeset(%{network_id: network_id, synced_height: 0, contract_search_count: 0, snippet_search_count: 0}) |> Repo.insert!()

      state ->
        state
    end
  end

  def get_synced_height(%Network{id: network_id}) do
    %{synced_height: synced_height} = get_by_network_id(network_id)
    synced_height
  end

  def update_height(%Network{id: network_id}, height) do
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
