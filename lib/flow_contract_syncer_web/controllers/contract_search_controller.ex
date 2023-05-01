defmodule FlowContractSyncerWeb.ContractSearchController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network, NetworkState}

  swagger_path :search do
    get("/api/v1/contracts/search")
    summary("Search contracts, order by dependants count desc")
    produces("application/json")
    tag("Search")
    operation_id("search_contract")

    security([%{Bearer: []}])

    parameters do
      keyword(:query, :string, "Keyword for searching, case-sensitive",
        required: true,
        example: "topshot"
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet, :testnet]
      )

      scope(
        :query,
        :string,
        "Search scope, should be \"code\" or \"uuid\" or \"uuid,code\". Default is \"uuid,code\". NOTE: Search in code is a bit slower than search in uuid",
        required: false
      )

      offset(:query, :integer, "Should be greater than 0, default value is 0", required: false)

      limit(:query, :integer, "The number of contracts, min: 1, max: 500, default: 200",
        required: false
      )
    end

    response(200, "OK", Schema.ref(:PartialContractsResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  @search_params_schema %{
    keyword: [type: :string, required: true, length: [min: 3]],
    network: [type: :string, in: ["mainnet", "testnet"], default: "mainnet"],
    scope: [type: :string, in: ["code", "uuid", "uuid,code", "code,uuid"], default: "uuid,code"],
    offset: [type: :integer, number: [min: 0], default: 0],
    limit: [type: :integer, number: [min: 1, max: 500], default: 200]
  }

  def search(conn, params) do
    Logger.info("[#{__MODULE__}] #{inspect(params)}")

    with {:ok,
          %{
            keyword: keyword,
            network: network,
            scope: scope,
            offset: offset,
            limit: limit
          }} <- Tarams.cast(params, @search_params_schema) do
      network = Repo.get_by(Network, name: network)
      state = NetworkState.get_by_network_id(network.id)
      NetworkState.inc_contract_search_count(state)

      %{contracts: contracts} = Contract.search(network, keyword, scope, offset, limit)
      render(conn, :contract_search, contracts: contracts)
    else
      {:error, errors} ->
        Logger.error(errors)

        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  def swagger_definitions do
    %{}
  end
end
