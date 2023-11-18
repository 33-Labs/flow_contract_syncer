defmodule FlowContractSyncerWeb.V2.StatusController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network, NetworkState}

  swagger_path :show do
    get("/api/v2/status")
    summary("Network status")
    produces("application/json")
    tag("Status")
    operation_id("get_network_status")

    security([%{Bearer: []}])

    parameters do
      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet, :testnet]
      )
    end

    response(200, "OK", Schema.ref(:StatusResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  @show_params_schema %{
    network: [type: :string, in: ["mainnet", "testnet"], default: "mainnet"]
  }

  def show(conn, params) do
    with {:ok, %{network: network}} <- Tarams.cast(params, @show_params_schema) do
      network = Repo.get_by(Network, name: network)
      network_state = NetworkState.get_by_network_id(network.id)
      contract_amount = Contract.total_amount(network)

      status = %{
        network: network.name,
        synced_height: network_state.synced_height,
        last_sync_at: network_state.updated_at,
        contract_amount: contract_amount,
        contract_search_count: network_state.contract_search_count
      }

      render(conn, :show, status: status)
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  def swagger_definitions do
    %{
      Status:
        swagger_schema do
          title("Status")
          description("Network status")

          properties do
            contract_amount(:integer, "Contracts amount synced", required: true)
            last_sync_at(:datetime, "Last time of contract syncing", required: true)
            network(:string, "Network name", required: true)
            synced_height(:integer, "The block height synced", required: true)
            contract_search_count(:integer, "The times of contract searched", required: true)
          end

          example(%{
            contract_amount: 2437,
            last_sync_at: "2022-12-05T02:54:46",
            network: "mainnet",
            synced_height: 42_168_691,
            contract_search_count: 100
          })
        end,
      StatusResp:
        swagger_schema do
          title("StatusResp")
          description("Status resp")

          properties do
            code(:integer, "status code", required: true)
            data(Schema.ref(:Status))
          end
        end
    }
  end
end
