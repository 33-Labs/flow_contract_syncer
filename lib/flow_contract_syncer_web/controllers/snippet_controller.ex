defmodule FlowContractSyncerWeb.SnippetController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network, Snippet}

  swagger_path :show do
    get("/api/v1/snippets/{code_hash}")
    summary("Query for specific snippet")
    produces("application/json")
    tag("Snippets")
    operation_id("query_snippet")

    security([%{Bearer: []}])

    parameters do
      code_hash(:path, :string, "Snippet code hash",
        required: true,
        example: "40E0416B13BC53F23FCB96FBCAF9E477621952650ADB4D93C2688D22E76EE2A2"
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet, :testnet]
      )
    end

    response(200, "OK", Schema.ref(:SnippetResp))
    response(404, "Snippet not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  defp show_params_schema,
    do: %{
      code_hash: [type: :string, required: true, cast_func: &code_hash_cast_func/1],
      network: [type: :string, in: ["mainnet", "testnet"], default: "mainnet"]
    }

  def show(conn, params) do
    with {:ok,
          %{
            network: network,
            code_hash: code_hash
          }} <- Tarams.cast(params, show_params_schema()) do
      network = Repo.get_by(Network, name: network)

      Snippet
      |> Repo.get_by(network_id: network.id, code_hash: code_hash)
      |> case do
        %Snippet{} = snippet ->
          contracts_count = Snippet.contracts_count(snippet)
          render(conn, :show, snippet: Map.put(snippet, :contracts_count, contracts_count))

        _otherwise ->
          conn
          |> put_status(:not_found)
          |> render(:error, code: 102, message: "snippet not found")
      end
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  swagger_path :contracts do
    get("/api/v1/snippets/{code_hash}/contracts")
    summary("Query the contracts using specific snippet")
    produces("application/json")
    tag("Snippets")
    operation_id("query_snippet_contracts")

    security([%{Bearer: []}])

    parameters do
      code_hash(:path, :string, "Snippet code hash",
        required: true,
        example: "40E0416B13BC53F23FCB96FBCAF9E477621952650ADB4D93C2688D22E76EE2A2"
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet, :testnet]
      )

      offset(:query, :integer, "Should be greater than 0, default value is 0", required: false)

      limit(:query, :integer, "The number of contracts, min: 1, max: 500, default: 200",
        required: false
      )
    end

    response(200, "OK", Schema.ref(:PartialContractsResp))
    response(404, "Snippet not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  defp contracts_params_schema,
    do: %{
      code_hash: [type: :string, required: true, cast_func: &code_hash_cast_func/1],
      network: [type: :string, in: ["mainnet", "testnet"], default: "mainnet"],
      offset: [type: :integer, number: [min: 0], default: 0],
      limit: [type: :integer, number: [min: 1, max: 500], default: 200]
    }

  def contracts(conn, params) do
    with {:ok,
          %{
            network: network,
            code_hash: code_hash,
            offset: offset,
            limit: limit
          }} <- Tarams.cast(params, contracts_params_schema()) do
      network = Repo.get_by(Network, name: network)

      Snippet
      |> Repo.get_by(network_id: network.id, code_hash: code_hash)
      |> case do
        %Snippet{} = snippet ->
          %{contracts: contracts} = Contract.use_snippet(snippet, offset, limit)
          render(conn, :contracts, contracts: contracts)

        _otherwise ->
          conn
          |> put_status(:not_found)
          |> render(:error, code: 102, message: "snippet not found")
      end
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  defp code_hash_cast_func(value) do
    case Base.decode64(value) do
      {:ok, _} -> {:ok, value}
      _otherwise -> {:error, "invalid_code_hash"}
    end
  end

  def swagger_definitions do
    %{}
  end
end
