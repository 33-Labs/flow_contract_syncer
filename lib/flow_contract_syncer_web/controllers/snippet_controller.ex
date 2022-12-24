defmodule FlowContractSyncerWeb.SnippetController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network, Snippet}

  swagger_path :show do
    get("/api/v1/snippets")
    summary("Query for specific snippet")
    produces("application/json")
    tag("Snippets")
    operation_id("query_snippet")

    security([%{Bearer: []}])

    parameters do
      code_hash(:path, :string, "Snippet code hash", required: true, example: "ltBsYqD8m0S/EEDaBv4jwRlO4jpGOqEWQ6SRWwzsxTA=")

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:ContractResp))
    response(404, "Contract not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  defp show_params_schema,
    do: %{
      code_hash: [type: :string, required: true, cast_func: &code_hash_cast_func/1],
      network: [type: :string, in: ["mainnet"], default: "mainnet"],
    }

  def show(conn, params) do
    with {:ok,
          %{
            network: network,
            code_hash: code_hash,
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

  defp contracts_params_schema,
  do: %{
    code_hash: [type: :string, required: true, cast_func: &code_hash_cast_func/1],
    network: [type: :string, in: ["mainnet"], default: "mainnet"],
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
        contracts = Contract.use_snippet(snippet, offset, limit)
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
