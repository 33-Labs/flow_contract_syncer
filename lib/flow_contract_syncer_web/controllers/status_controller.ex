defmodule FlowContractSyncerWeb.StatusController do
  use FlowContractSyncerWeb, :controller

  require Logger

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.{Network, NetworkState}

  def show(conn, %{"network" => "mainnet"}) do
    network = Repo.get_by(Network, name: "mainnet")
    network_state = NetworkState.get_by_network_id(network.id)

    status = %{
      network: network.name,
      synced_height: network_state.synced_height,
      last_sync_at: network_state.updated_at
    }

    render(conn, :show, status: status)
  end

  def show(conn, %{"network" => _network}) do
    render(conn, :error, code: 100, message: "unsupported")
  end

  def show(conn, params) do
    show(conn, Map.put(params, "network", "mainnet")) 
  end
end
