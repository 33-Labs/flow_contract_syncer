defmodule FlowContractSyncerWeb.ContractController do
  use FlowContractSyncerWeb, :controller

  require Logger

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.{Contract, Network}

  def show(conn, %{"uuid" => uuid, "network" => "mainnet"}) do
    network = Repo.get_by(Network, name: "mainnet")
    uuid = String.trim(uuid)

    contract = 
      Contract
      |> Repo.get_by(network_id: network.id, uuid: uuid)
      |> Repo.preload([:dependencies, :dependants])

    case contract do
      nil -> render(conn, :error, code: 102, message: "contract not found")
      %Contract{} = contract -> render(conn, :show, contract: contract)
    end
  end

  def show(conn, %{"uuid" => _uuid, "network" => _network}) do
    render(conn, :error, code: 100, message: "unsupported")
  end

  def show(conn, %{"uuid" => uuid}) do
    show(conn, %{"uuid" => uuid, "network" => "mainnet"})
  end
  
end