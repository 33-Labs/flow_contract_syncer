defmodule FlowContractSyncerWeb.ContractSearchController do

  use FlowContractSyncerWeb, :controller
  import Ecto.Query

  require Logger

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.Contract
  
  def search(conn, %{"query" => query, "network" => "mainnet"}) do
    query = String.replace(query, ~r/\W/u, "")

    like = "%#{query}%"
    contracts = 
      from(c in Contract,
        where: ilike(c.code, ^like) or ilike(c.uuid, ^like))
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
    render(conn, :error, code: 400, message: "unsupported")
  end

  def search(conn, %{"query" => query}) do
    search(conn, %{"query" => query, "network" => "mainnet"})
  end
end