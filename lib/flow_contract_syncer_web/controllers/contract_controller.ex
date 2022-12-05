defmodule FlowContractSyncerWeb.ContractController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{ContractSyncer, Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network}

  swagger_path :show do
    get("/api/v1/contracts")
    summary("Query for contract")
    produces("application/json")
    tag("Contracts")
    operation_id("query_contract")

    security([%{Bearer: []}])

    parameters do
      uuid(:query, :string, "Contract uuid", required: true, example: "A.0b2a3299cc857e29.TopShot")

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:ContractResp))
    response(404, "Contract not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  def show(conn, %{"uuid" => uuid, "network" => "mainnet"}) do
    network = Repo.get_by(Network, name: "mainnet")
    uuid = String.trim(uuid)

    contract = Repo.get_by(Contract, network_id: network.id, uuid: uuid)

    case contract do
      nil ->
        render(put_status(conn, :not_found), :error, code: 102, message: "contract not found")

      %Contract{} = contract ->
        render(conn, :show, contract: contract)
    end
  end

  def show(conn, %{"network" => network}) when network != "mainnet" do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, code: 100, message: "unsupported")
  end

  def show(conn, %{"uuid" => _uuid} = params) do
    show(conn, Map.put(params, "network", "mainnet"))
  end

  def show(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, code: 104, message: "invalid params")
  end

  swagger_path :latest do
    get("/api/v1/contracts/latest")
    summary("Query latest contracts")
    produces("application/json")
    tag("Contracts")
    operation_id("query_latest_contract")

    security([%{Bearer: []}])

    parameters do
      size(:query, :integer, "The number of latest contracts, should not be greater than 10",
        required: false
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:BasicContractsResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  def latest(conn, %{"size" => size, "network" => "mainnet"}) do
    network = Repo.get_by(Network, name: "mainnet")
    size = if is_integer(size), do: size, else: String.to_integer(size)

    if size <= 10 do
      contracts = Contract.latest(network, size)
      render(conn, :latest, contracts: contracts)
    else
      conn
      |> put_status(:unprocessable_entity)
      |> render(:error, code: 108, message: "size should not be greater than 10")
    end
  rescue
    _ ->
      conn
      |> put_status(:unprocessable_entity)
      |> render(:error, code: 104, message: "invalid params")
  end

  def latest(conn, %{"network" => network}) when network != "mainnet" do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, code: 100, message: "unsupported")
  end

  def latest(conn, %{"size" => _size} = params) do
    latest(conn, params |> Map.put("network", "mainnet"))
  end

  def latest(conn, params) do
    latest(conn, params |> Map.put("size", "10") |> Map.put("network", "mainnet"))
  end

  swagger_path :sync do
    get("/api/v1/contracts/sync")
    summary("Sync contract manually by uuid")
    produces("application/json")
    tag("Contracts")
    operation_id("sync_contract")

    security([%{Bearer: []}])

    parameters do
      uuid(:query, :string, "Contract uuid", required: true, example: "A.0b2a3299cc857e29.TopShot")

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:ContractResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  def sync(conn, %{"uuid" => uuid, "network" => "mainnet"}) do
    network = Repo.get_by(Network, name: "mainnet")
    uuid = String.trim(uuid)

    case uuid |> String.split(".") do
      ["A", raw_address, name] ->
        address = Utils.normalize_address("0x" <> raw_address)

        case ContractSyncer.sync_contract(network, address, name, :normal) do
          {:ok, contract} ->
            render(conn, :show, contract: contract)

          {:error, error} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(:error, code: 106, message: "#{inspect(error)}")
        end

      _otherwise ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: "invalid params")
    end
  end

  def sync(conn, %{"network" => network}) when network != "mainnet" do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, code: 100, message: "unsupported")
  end

  def sync(conn, %{"uuid" => _uuid} = params) do
    sync(conn, Map.put(params, "network", "mainnet"))
  end

  def sync(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, code: 104, message: "invalid params")
  end

  def swagger_definitions do
    %{
      Contract:
        swagger_schema do
          title("Contract")
          description("A contract on the network")

          properties do
            uuid(:string, "Contract uuid", required: true)
            address(:string, "Contract address", required: true)
            name(:string, "Contract name", required: true)
            code(:string, "Contract code", required: true)

            dependencies(:array, "The uuids of contracts imported by this contract",
              required: true
            )

            dependants(:array, "The uuids of contracts which import this contract", required: true)
          end

          example(%{
            uuid: "A.0b2a3299cc857e29.TopShot",
            address: "0x0b2a3299cc857e29",
            name: "TopShot",
            code: "...",
            dependencies: ["A.1d7e57aa55817448.MetadataViews"],
            dependants: ["A.c1e4f4f4c4257510.TopShotMarketV3"]
          })
        end,
      ContractResp:
        swagger_schema do
          title("ContractResp")
          description("Contract resp")

          properties do
            code(:integer, "status code", required: true)
            data(Schema.ref(:Contract))
          end
        end,
      BasicContract:
        swagger_schema do
          description("Basic info of a contract on the network")

          properties do
            uuid(:string, "Contract uuid", required: true)

            dependencies_count(:integer, "The amount of contracts imported by this contract",
              required: true
            )

            dependants_count(:integer, "The amount of contracts which import this contract",
              required: true
            )
          end

          example(%{
            uuid: "A.0b2a3299cc857e29.TopShot",
            dependencies_count: 10,
            dependants_count: 10
          })
        end,
      BasicContracts:
        swagger_schema do
          title("BasicContracts")
          description("A collection of BasicContracts")
          type(:array)
          items(Schema.ref(:BasicContract))
        end,
      BasicContractsResp:
        swagger_schema do
          title("BasicContractsResp")
          description("BasicContracts resp")

          properties do
            code(:integer, "status code", required: true)
            data(Schema.ref(:BasicContracts))
          end
        end,
      ErrorResp:
        swagger_schema do
          properties do
            code(:integer, "Error code", required: true)
            message(:string, "Error message", required: true)
          end

          example(%{
            code: 100,
            message: "unsupported"
          })
        end
    }
  end
end
