defmodule FlowContractSyncerWeb.ContractController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{ContractSyncer, Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network}

  swagger_path :show do
    get("/api/v1/contracts")
    summary("Query for specific contract")
    produces("application/json")
    tag("Contracts")
    operation_id("query_contract")

    security([%{Bearer: []}])

    parameters do
      uuid(:path, :string, "Contract uuid", required: true, example: "A.0b2a3299cc857e29.TopShot")

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )

      sync(
        :query,
        :bool,
        "Should sync the latest version from the blockchain before showing the contract",
        default: false
      )
    end

    response(200, "OK", Schema.ref(:ContractResp))
    response(404, "Contract not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  defp show_params_schema,
    do: %{
      uuid: [type: :string, required: true, cast_func: &uuid_cast_func/1],
      network: [type: :string, in: ["mainnet"], default: "mainnet"],
      sync: [type: :boolean, default: false]
    }

  def show(conn, params) do
    with {:ok,
          %{
            network: network,
            uuid: uuid,
            sync: should_sync
          }} <- Tarams.cast(params, show_params_schema()) do
      network = Repo.get_by(Network, name: network)
      uuid = String.trim(uuid)

      contract_res =
        if should_sync do
          ["A", raw_address, name] = uuid |> String.split(".")
          address = Utils.normalize_address("0x" <> raw_address)
          ContractSyncer.sync_contract(network, address, name, :normal)
        else
          case Repo.get_by(Contract, network_id: network.id, uuid: uuid) do
            %Contract{} = contract -> {:ok, contract}
            _otherwise -> {:error, :not_found}
          end
        end

      case contract_res do
        {:ok, %Contract{} = contract} ->
          render(conn, :show, contract: contract)

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> render(:error, code: 102, message: "contract not found")

        {:error, _error} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(:error, code: 104, message: "invalid params")
      end
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  swagger_path :index do
    get("/api/v1/contracts")
    summary("Query contracts")
    produces("application/json")
    tag("Contracts")
    operation_id("query_contracts")

    security([%{Bearer: []}])

    parameters do
      sort_by(:query, :string, "The field sort by",
        required: true,
        enum: [:inserted_at, :dependencies_count, :dependants_count]
      )

      order_by(:query, :string, "Ascend or descend",
        required: false,
        enum: [:asc, :desc]
      )

      size(:query, :integer, "The number of contracts, should not be greater than 20",
        required: false
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:PartialContractsResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  def index_params_schema,
    do: %{
      owner: [type: :string],
      order_by: [
        type: :string,
        in: ["inserted_at", "dependants_count", "dependencies_count"],
        default: "inserted_at"
      ],
      order_by_direction: [type: :string, in: ["desc", "asc"], default: "desc"],
      offset: [type: :integer, number: [min: 0], default: 0],
      limit: [type: :integer, number: [min: 1, max: 500], default: 200],
      network: [type: :string, in: ["mainnet"], default: "mainnet"]
    }

  def index(conn, params) do
    with {:ok,
          %{
            network: network,
            owner: owner,
            order_by: order_by,
            order_by_direction: direction,
            offset: offset,
            limit: limit
          }} <- Tarams.cast(params, index_params_schema()) do
      network = Repo.get_by(Network, name: network)

      contracts =
        case order_by do
          "inserted_at" ->
            Contract.order_by(:inserted_at, network, owner, direction, offset, limit)

          "dependants_count" ->
            Contract.order_by(:dependants_count, network, owner, direction, offset, limit)

          "dependencies_count" ->
            Contract.order_by(:dependencies_count, network, owner, direction, offset, limit)
        end

      render(conn, :index, contracts: contracts)
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  def snippets_params_schema,
    do: %{
      uuid: [type: :string, required: true, cast_func: &uuid_cast_func/1],
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
      network: [type: :string, in: ["mainnet"], default: "mainnet"]
    }

  def snippets(conn, params) do
    with {:ok,
          %{
            network: network,
            uuid: uuid,
            type: type
          }} <- Tarams.cast(params, snippets_params_schema()) do
      network = Repo.get_by(Network, name: network)
      contract = Repo.get_by(Contract, uuid: uuid, network_id: network.id)

      types = case type do
        "interface" -> [:resource_interface, :struct_interface]
        otherwise -> [String.to_atom(otherwise)]
      end

      snippets =
        Contract.snippets(contract, types)

      render(conn, snippets: snippets)
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  def dependencies_params_schema,
    do: %{
      uuid: [type: :string, required: true, cast_func: &uuid_cast_func/1],
      order_by: [type: :string, in: ["address", "name"], default: "address"],
      order_by_direction: [type: :string, in: ["desc", "asc"], default: "desc"],
      offset: [type: :integer, number: [min: 0], default: 0],
      limit: [type: :integer, number: [min: 1, max: 500], default: 200],
      network: [type: :string, in: ["mainnet"], default: "mainnet"]
    }

  def dependencies(conn, params) do
    with {:ok,
          %{
            network: network,
            uuid: uuid,
            order_by: order_by,
            order_by_direction: direction,
            offset: offset,
            limit: limit
          }} <- Tarams.cast(params, dependencies_params_schema()) do
      network = Repo.get_by(Network, name: network)
      contract = Repo.get_by(Contract, uuid: uuid, network_id: network.id)

      dependencies_count = Contract.dependencies_count(contract)

      dependencies =
        Contract.dependencies(contract, String.to_atom(order_by), direction, offset, limit)

      render(conn, :dependencies,
        uuid: contract.uuid,
        dependencies: dependencies,
        dependencies_count: dependencies_count
      )
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  def dependants_params_schema,
    do: %{
      uuid: [type: :string, required: true, cast_func: &uuid_cast_func/1],
      order_by: [type: :string, in: ["address", "name"], default: "address"],
      order_by_direction: [type: :string, in: ["desc", "asc"], default: "desc"],
      offset: [type: :integer, number: [min: 0], default: 0],
      limit: [type: :integer, number: [min: 1, max: 500], default: 200],
      network: [type: :string, in: ["mainnet"], default: "mainnet"]
    }

  def dependants(conn, params) do
    with {:ok,
          %{
            network: network,
            uuid: uuid,
            order_by: order_by,
            order_by_direction: direction,
            offset: offset,
            limit: limit
          }} <- Tarams.cast(params, dependants_params_schema()) do
      network = Repo.get_by(Network, name: network)
      contract = Repo.get_by(Contract, uuid: uuid, network_id: network.id)

      dependants_count = Contract.dependants_count(contract)

      dependants =
        Contract.dependants(contract, String.to_atom(order_by), direction, offset, limit)

      render(conn, :dependants,
        uuid: contract.uuid,
        dependants: dependants,
        dependants_count: dependants_count
      )
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  defp uuid_cast_func(value) do
    if Utils.is_valid_uuid(value) do
      {:ok, value}
    else
      {:error, "invalid uuid"}
    end
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
      PartialContract:
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
      PartialContracts:
        swagger_schema do
          title("PartialContracts")
          description("A collection of PartialContracts")
          type(:array)
          items(Schema.ref(:PartialContract))
        end,
      PartialContractsResp:
        swagger_schema do
          title("PartialContractsResp")
          description("PartialContracts resp")

          properties do
            code(:integer, "status code", required: true)
            data(Schema.ref(:PartialContracts))
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
