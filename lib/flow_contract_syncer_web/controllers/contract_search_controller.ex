defmodule FlowContractSyncerWeb.ContractSearchController do
  use FlowContractSyncerWeb, :controller
  import Ecto.Query

  require Logger

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.{Contract, Network}

  def search(conn, %{"query" => query, "network" => "mainnet", "scope" => "uuid"}) do
    network = Repo.get_by(Network, name: "mainnet")
    query = String.replace(query, ~r/\W/u, "")

    like = "%#{query}%"

    contracts =
      from(c in Contract,
        where: c.network_id == ^network.id and ilike(c.uuid, ^like)
      )
      |> Repo.all()

    render(conn, :contract_search, contracts: contracts)
  end

  def search(conn, %{"query" => query, "network" => "mainnet", "scope" => "code"}) do
    network = Repo.get_by(Network, name: "mainnet")
    query = String.replace(query, ~r/\W/u, "")

    like = "%#{query}%"

    contracts =
      from(c in Contract,
        where: c.network_id == ^network.id and ilike(c.code, ^like)
      )
      |> Repo.all()

    render(conn, :contract_search, contracts: contracts)
  end

  def search(conn, %{"query" => query, "network" => "mainnet", "scope" => scope})
      when scope in ["uuid,code", "code,uuid"] do
    network = Repo.get_by(Network, name: "mainnet")
    query = String.replace(query, ~r/\W/u, "")

    like = "%#{query}%"

    contracts =
      from(c in Contract,
        where: c.network_id == ^network.id and (ilike(c.code, ^like) or ilike(c.uuid, ^like))
      )
      |> Repo.all()

    render(conn, :contract_search, contracts: contracts)
  end

  def search(conn, %{"query" => query, "network" => "mainnet", "scope" => _scope}) do
    render(conn, :error, code: 105, message: "scope should be uuid or code or uuid,code")
  end

  def search(conn, %{"query" => query, "network" => "mainnet"} = params) do
    search(conn, Map.put(params, "scope", "uuid,code"))
  end

  def search(conn, %{"query" => _query, "network" => _network}) do
    render(conn, :error, code: 100, message: "unsupported")
  end

  def search(conn, %{"query" => _query} = params) do
    search(conn, Map.put(params, "network", "mainnet"))
  end

  def search(conn, _params) do
    render(conn, :error, code: 104, message: "invalid params")
  end
end
