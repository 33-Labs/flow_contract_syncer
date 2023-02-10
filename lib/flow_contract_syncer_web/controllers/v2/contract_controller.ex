defmodule FlowContractSyncerWeb.V2.ContractController do
  use FlowContractSyncerWeb, :controller
  use PhoenixSwagger

  require Logger

  alias FlowContractSyncer.{ContractSyncer, Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network}

  swagger_path :index do
    get("/api/v1/contracts")
    summary("Query contracts")
    produces("application/json")
    tag("Contracts")
    operation_id("query_contracts")

    security([%{Bearer: []}])

    parameters do
      owner(:query, :string, "The owner of contracts")

      order_by(
        :query,
        :string,
        "Should be one of inserted_at, dependants_count, dependencies_count, default is inserted_at",
        enum: [:inserted_at, :dependencies_count, :dependants_count],
        default: :inserted_at
      )

      order_by_direction(:query, :string, "Ascend or descend",
        required: false,
        enum: [:asc, :desc]
      )

      offset(:query, :integer, "Should be greater than 0, default value is 0", required: false)

      limit(:query, :integer, "The number of contracts, min: 1, max: 500, default: 200",
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

      %{count: count, contracts: contracts} =
        case order_by do
          "inserted_at" ->
            Contract.order_by(:inserted_at, network, owner, direction, offset, limit)

          "dependants_count" ->
            Contract.order_by(:dependants_count, network, owner, direction, offset, limit)

          "dependencies_count" ->
            Contract.order_by(:dependencies_count, network, owner, direction, offset, limit)
        end

      render(conn, :index, count: count, contracts: contracts)
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  swagger_path :snippets do
    get("/api/v1/contracts/{uuid}/snippets")
    summary("Query contract snippets")
    produces("application/json")
    tag("Contracts")
    operation_id("query_contract_sinppets")

    security([%{Bearer: []}])

    parameters do
      uuid(:path, :string, "Contract uuid", required: true, example: "A.0b2a3299cc857e29.TopShot")

      type(:query, :string, "Snippet type",
        enum: [:resource, :struct, :interface, :function, :enum, :event, :all],
        default: :all
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:SnippetsResp))
    response(404, "Contract not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
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

      case contract do
        nil ->
          conn
          |> put_status(:not_found)
          |> render(:error, code: 102, message: "contract not found")

        %Contract{} = contract ->
          types =
            case type do
              "interface" -> [:resource_interface, :struct_interface]
              otherwise -> [String.to_atom(otherwise)]
            end

          snippets = Contract.snippets(contract, types)
          render(conn, snippets: snippets)
      end
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  swagger_path :deployments do
    get("/api/v1/contracts/{uuid}/deployments")
    summary("Query contract deployments")
    produces("application/json")
    tag("Contracts")
    operation_id("query_contract_deployments")

    security([%{Bearer: []}])

    parameters do
      uuid(:path, :string, "Contract uuid", required: true, example: "A.0b2a3299cc857e29.TopShot")

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:DeploymentsResp))
    response(404, "Contract not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  def deployments_params_schema,
    do: %{
      uuid: [type: :string, required: true, cast_func: &uuid_cast_func/1],
      network: [type: :string, in: ["mainnet"], default: "mainnet"]
    }

  def deployments(conn, params) do
    with {:ok,
          %{
            network: network,
            uuid: uuid
          }} <- Tarams.cast(params, deployments_params_schema()) do
      network = Repo.get_by(Network, name: network)
      contract = Repo.get_by(Contract, uuid: uuid, network_id: network.id)

      case contract do
        nil ->
          conn
          |> put_status(:not_found)
          |> render(:error, code: 102, message: "contract not found")

        %Contract{} = contract ->
          events = Contract.events(contract)
          render(conn, deployments: events)
      end
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  swagger_path :dependencies do
    get("/api/v1/contracts/{uuid}/dependencies")
    summary("Query contract dependencies")
    produces("application/json")
    tag("Contracts")
    operation_id("query_contract_dependencies")

    security([%{Bearer: []}])

    parameters do
      uuid(:path, :string, "Contract uuid", required: true, example: "A.0b2a3299cc857e29.TopShot")

      order_by(
        :query,
        :string,
        "Should be one of address, name, dependants_count, default is dependants_count",
        enum: [:address, :name, :dependants_count],
        default: :address
      )

      order_by_direction(:query, :string, "Ascend or descend",
        required: false,
        enum: [:asc, :desc]
      )

      offset(:query, :integer, "Should be greater than 0, default value is 0", required: false)

      limit(:query, :integer, "The number of contracts, min: 1, max: 500, default: 200",
        required: false
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:UUIDsResp))
    response(404, "Contract not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  def dependencies_params_schema,
    do: %{
      uuid: [type: :string, required: true, cast_func: &uuid_cast_func/1],
      order_by: [
        type: :string,
        in: ["address", "name", "dependants_count"],
        default: "dependants_count"
      ],
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

      case contract do
        nil ->
          conn
          |> put_status(:not_found)
          |> render(:error, code: 102, message: "contract not found")

        %Contract{} = contract ->
          dependencies_count = Contract.dependencies_count(contract)

          dependencies =
            Contract.dependencies(contract, String.to_atom(order_by), direction, offset, limit)

          render(conn, :dependencies,
            uuid: contract.uuid,
            dependencies: dependencies,
            dependencies_count: dependencies_count
          )
      end
    else
      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, code: 104, message: Utils.format_errors(errors))
    end
  end

  swagger_path :dependants do
    get("/api/v1/contracts/{uuid}/dependants")
    summary("Query contract dependants")
    produces("application/json")
    tag("Contracts")
    operation_id("query_contract_dependants")

    security([%{Bearer: []}])

    parameters do
      uuid(:path, :string, "Contract uuid", required: true, example: "A.0b2a3299cc857e29.TopShot")

      order_by(
        :query,
        :string,
        "Should be one of address, name, dependants_count, default is dependants_count",
        enum: [:address, :name, :dependants_count],
        default: :address
      )

      order_by_direction(:query, :string, "Ascend or descend",
        required: false,
        enum: [:asc, :desc]
      )

      offset(:query, :integer, "Should be greater than 0, default value is 0", required: false)

      limit(:query, :integer, "The number of contracts, min: 1, max: 500, default: 200",
        required: false
      )

      network(:query, :string, "Flow network, default value is \"mainnet\"",
        required: false,
        enum: [:mainnet]
      )
    end

    response(200, "OK", Schema.ref(:UUIDsResp))
    response(404, "Contract not found", Schema.ref(:ErrorResp))
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResp))
  end

  def dependants_params_schema,
    do: %{
      uuid: [type: :string, required: true, cast_func: &uuid_cast_func/1],
      order_by: [
        type: :string,
        in: ["address", "name", "dependants_count"],
        default: "dependants_count"
      ],
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

      case contract do
        nil ->
          conn
          |> put_status(:not_found)
          |> render(:error, code: 102, message: "contract not found")

        %Contract{} = contract ->
          dependants_count = Contract.dependants_count(contract)

          dependants =
            Contract.dependants(contract, String.to_atom(order_by), direction, offset, limit)

          render(conn, :dependants,
            uuid: contract.uuid,
            dependants: dependants,
            dependants_count: dependants_count
          )
      end
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

            dependencies_count(:integer, "The number of contracts imported by this contract",
              required: true
            )

            dependants_count(:integer, "The number of contracts which import this contract",
              required: true
            )

            events(:array, "The events in the contract", required: true)
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
          description("A collection of PartialContract")
          type(:array)
          items(Schema.ref(:PartialContract))
        end,
      PartialContractsResp:
        swagger_schema do
          title("PartialContractsResp")
          description("PartialContracts resp")

          properties do
            code(:integer, "Status code", required: true)
            data(Schema.ref(:PartialContracts))
          end
        end,
      Snippet:
        swagger_schema do
          title("Snippet")
          description("Snippet")

          properties do
            code(:string, "Snippet code", required: true)
            code_hash(:string, "Snippet code hash", required: true)
            contracts_count(:integer, "Contracts using this snippet", required: true)
            type(:string, "Snippet type", required: true)
          end

          example(%{
            code: "pub event TokensDeposited(amount: UFix64, to: Address?)",
            code_hash: "DFFEFBF8AEBB86680E0EBABAF266F45B68A28188E3E17E81882465A910F1D80A",
            contracts_count: 160,
            type: "event"
          })
        end,
      SnippetResp:
        swagger_schema do
          title("SnippetResp")
          description("Snippet resp")

          properties do
            code(:integer, "Status code", required: true)
            data(Schema.ref(:Snippet))
          end
        end,
      Snippets:
        swagger_schema do
          title("Snippets")
          description("A collection of Snippet")
          type(:array)
          items(Schema.ref(:Snippet))
        end,
      SnippetsResp:
        swagger_schema do
          title("SnippetsResp")
          description("Snippets resp")

          properties do
            code(:integer, "Status code", required: true)
            data(Schema.ref(:Snippets))
          end
        end,
      Deployment:
        swagger_schema do
          title("Deployment")
          description("Deployment")

          properties do
            block_height(:integer, "Block height of the deployment", required: true)
            block_timestamp(:string, "Block timestamp of the deployment", required: true)
            tx_id(:string, "Transaction hash of the deployment", required: true)
            type(:string, "Contract event type", required: true)
          end

          example(%{
            block_height: 23_227_064,
            block_timestamp: "2022-01-25T22:34:48.000000",
            tx_id: "4a03653ecdb5d8fdf11c9f5a967fa126dba725da11a4d87a5fb805478b23e5ee",
            type: "added"
          })
        end,
      Deployments:
        swagger_schema do
          title("Deployments")
          description("A collection of Deployment")
          type(:array)
          items(Schema.ref(:Deployment))
        end,
      DeploymentsResp:
        swagger_schema do
          title("DeploymentsResp")
          description("Deployments resp")

          properties do
            code(:integer, "Status code", required: true)
            data(Schema.ref(:Deployments))
          end
        end,
      UUIDs:
        swagger_schema do
          properties do
            dependencies(:string, "Dependencies list", required: true)
            total_dependencies_count(:integer, "Dependencies count", required: true)
            uuid(:string, "Contract uuid", required: true)
          end

          example(%{
            dependencies: [
              "A.f233dcee88fe0abe.FungibleToken",
              "A.1d7e57aa55817448.NonFungibleToken"
            ],
            total_dependencies_count: 2,
            uuid: "A.1d7e57aa55817448.MetadataViews"
          })
        end,
      UUIDsResp:
        swagger_schema do
          title("UUIDsResp")
          description("UUIDs resp")

          properties do
            code(:integer, "status code", required: true)
            data(Schema.ref(:UUIDs))
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
