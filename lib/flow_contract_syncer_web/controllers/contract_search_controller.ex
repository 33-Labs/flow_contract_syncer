defmodule FlowContractSyncerWeb.ContractSearchController do

  use FlowContractSyncerWeb, :controller
  import Ecto.Query

  require Logger

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.{Contract, Network}

  def search(conn, %{"query" => query, "network" => "mainnet"}) do
    network = Repo.get_by(Network, name: "mainnet")
    query = String.replace(query, ~r/\W/u, "")

    like = "%#{query}%"
    contracts =
      from(c in Contract,
        where: c.network_id == ^network.id and (ilike(c.code, ^like) or ilike(c.uuid, ^like)))
      |> Repo.all()
      |> Repo.preload([:dependants, :dependencies])
      |> Enum.map(fn contract ->
        %{
          id: contract.id,
          uuid: contract.uuid,
          dependencies_count: contract.dependencies |> Enum.count(),
          dependants_count: contract.dependants |> Enum.count()
        }
      end)

    render(conn, :contract_search, contracts: contracts)
  end

  def search(conn, %{"query" => _query, "network" => _network}) do
    render(conn, :error, code: 100, message: "unsupported")
  end

  def search(conn, %{"query" => query}) do
    search(conn, %{"query" => query, "network" => "mainnet"})
  end
end