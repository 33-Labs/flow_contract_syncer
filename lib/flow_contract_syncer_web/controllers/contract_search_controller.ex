defmodule FlowContractSyncerWeb.ContractSearchController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  import Ecto.Query

  require Logger

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.{Contract, Network}

  swagger_path :search do
    get("/api/v1/search")
    summary("Search contract")
    produces("application/json")
    tag("Search")
    operation_id("search_contract")

    security([%{Bearer: []}])

    parameters do
      query(:query, :string, "Keyword for searching, case-insensitive",
        required: true,
        example: "topshot"
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )

      scope(
        :query,
        :string,
        "Search scope, should be \"code\" or \"uuid\" or \"uuid,code\". Default is \"uuid,code\". NOTE: Search in code is a bit slower than search in uuid",
        required: false
      )
    end

    response(200, "OK", Schema.ref(:BasicContractsResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  def search(conn, %{"query" => query, "network" => "mainnet", "scope" => "uuid"}) do
    network = Repo.get_by(Network, name: "mainnet")
    query = String.replace(query, ~r/(?!\.)\W/u, "")

    search_term = "#{query}:*"

    # SELECT * FROM contracts WHERE to_tsvector('english', uuid || ' ' || coalesce(code, ' ')) @@ to_tsquery('fungible:*');
    contracts =
      from(c in Contract,
        where:
          c.network_id == ^network.id and
            fragment(
              "to_tsvector('english', uuid) @@ to_tsquery(?)",
              ^search_term
            )
      )
      |> Repo.all()

    render(conn, :contract_search, contracts: contracts)
  end

  def search(conn, %{"query" => query, "network" => "mainnet", "scope" => "code"}) do
    network = Repo.get_by(Network, name: "mainnet")
    query = String.replace(query, ~r/(?!\.)\W/u, "")

    search_term = "#{query}:*"

    # SELECT * FROM contracts WHERE to_tsvector('english', uuid || ' ' || coalesce(code, ' ')) @@ to_tsquery('fungible:*');
    contracts =
      from(c in Contract,
        where:
          c.network_id == ^network.id and
            fragment(
              "to_tsvector('english', coalesce(code, ' ')) @@ to_tsquery(?)",
              ^search_term
            )
      )
      |> Repo.all()

    render(conn, :contract_search, contracts: contracts)
  end

  def search(conn, %{"query" => query, "network" => "mainnet", "scope" => scope})
      when scope in ["uuid,code", "code,uuid"] do
    network = Repo.get_by(Network, name: "mainnet")
    query = String.replace(query, ~r/(?!\.)\W/u, "")

    search_term = "#{query}:*"

    # SELECT * FROM contracts WHERE to_tsvector('english', uuid || ' ' || coalesce(code, ' ')) @@ to_tsquery('fungible:*');
    contracts =
      from(c in Contract,
        where:
          c.network_id == ^network.id and
            fragment(
              "to_tsvector('english', uuid || ' ' || coalesce(code, ' ')) @@ to_tsquery(?)",
              ^search_term
            )
      )
      |> Repo.all()

    render(conn, :contract_search, contracts: contracts)
  end

  def search(conn, %{"query" => _query, "network" => "mainnet"} = params) do
    search(conn, Map.put(params, "scope", "uuid,code"))
  end

  def search(conn, %{"scope" => scope})
      when scope not in ["code", "uuid", "uuid,code", "code,uuid"] do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, code: 105, message: "scope should be uuid or code or uuid,code")
  end

  def search(conn, %{"network" => network}) when network != "mainnet" do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, code: 100, message: "unsupported")
  end

  def search(conn, %{"query" => _query} = params) do
    search(conn, Map.put(params, "network", "mainnet"))
  end

  def search(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, code: 104, message: "invalid params")
  end

  def swagger_definitions do
    %{}
  end
end
