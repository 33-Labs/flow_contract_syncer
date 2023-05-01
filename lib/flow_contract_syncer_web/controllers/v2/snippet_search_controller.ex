defmodule FlowContractSyncerWeb.V2.SnippetSearchController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{Repo, Utils}
  alias FlowContractSyncer.Schema.{Network, NetworkState, Snippet}

  swagger_path :search do
    get("/api/v2/snippets/search")
    summary("Search snippets")
    produces("application/json")
    tag("Search")
    operation_id("search_snippets")

    security([%{Bearer: []}])

    parameters do
      keyword(:query, :string, "Keyword for searching, case-insensitive",
        required: true,
        example: "topshot"
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet, :testnet]
      )

      type(
        :query,
        :string,
        "Should be one of all, resource, struct, interface, function, enum, event, default is all",
        required: false
      )

      offset(:query, :integer, "Should be greater than 0, default value is 0", required: false)

      limit(:query, :integer, "The number of contracts, min: 1, max: 500, default: 200",
        required: false
      )
    end

    response(200, "OK", Schema.ref(:SnippetsResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  @search_params_schema %{
    keyword: [type: :string, required: true, length: [min: 3]],
    network: [type: :string, in: ["mainnet", "testnet"], default: "mainnet"],
    type: [
      type: :string,
      in: [
        "resource",
        "struct",
        "interface",
        "function",
        "enum",
        "event",
        "all"
      ],
      default: "all"
    ],
    offset: [type: :integer, number: [min: 0], default: 0],
    limit: [type: :integer, number: [min: 1, max: 500], default: 200]
  }

  def search(conn, params) do
    with {:ok,
          %{
            keyword: keyword,
            network: network,
            type: type,
            offset: offset,
            limit: limit
          }} <- Tarams.cast(params, @search_params_schema) do
      network = Repo.get_by(Network, name: network)
      state = NetworkState.get_by_network_id(network.id)
      NetworkState.inc_snippet_search_count(state)

      %{count: count, snippets: snippets} = Snippet.search(network, keyword, type, offset, limit)
      render(conn, :snippet_search, snippets: snippets, count: count)
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
