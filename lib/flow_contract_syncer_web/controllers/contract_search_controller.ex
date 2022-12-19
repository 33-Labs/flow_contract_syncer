defmodule FlowContractSyncerWeb.ContractSearchController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network}

  swagger_path :search do
    get("/api/v1/search")
    summary("Search contract")
    produces("application/json")
    tag("Search")
    operation_id("search_contract")

    security([%{Bearer: []}])

    parameters do
      keyword(:query, :string, "Keyword for searching, case-insensitive",
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

    response(200, "OK", Schema.ref(:PartialContractsResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  @search_params_schema %{
    keyword: [type: :string, required: true, length: [min: 3]],
    network: [type: :string, in: ["mainnet"], default: "mainnet"],
    scope: [type: :string, in: ["code", "uuid", "uuid,code", "code,uuid"], default: ["uuid,code"]]
  }

  def search(conn, params) do
    with {:ok,
          %{
            keyword: keyword,
            network: network,
            scope: scope
          }} <- Tarams.cast(params, @search_params_schema) do
      network = Repo.get_by(Network, name: network)
      contracts = Contract.search(network, keyword, scope)
      render(conn, :contract_search, contracts: contracts)
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  def swagger_definitions do
    %{}
  end
end
