defmodule FlowContractSyncerWeb.ContractController do
  use FlowContractSyncerWeb, :controller

  require Logger

  alias FlowContractSyncer.{ContractSyncer, Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Network}

  def show(conn, %{"uuid" => uuid, "network" => "mainnet"}) do
    network = Repo.get_by(Network, name: "mainnet")
    uuid = String.trim(uuid)

    contract = Repo.get_by(Contract, network_id: network.id, uuid: uuid)

    case contract do
      nil -> render(conn, :error, code: 102, message: "contract not found")
      %Contract{} = contract -> render(conn, :show, contract: contract)
    end
  end

  def show(conn, %{"uuid" => _uuid, "network" => _network}) do
    render(conn, :error, code: 100, message: "unsupported")
  end

  def show(conn, %{"uuid" => _uuid} = params) do
    show(conn, Map.put(params, "network", "mainnet"))
  end

  def latest(conn, %{"size" => size}) do
    size = String.to_integer(size)

    if size <= 10 do
      contracts = Contract.latest(size)
      render(conn, :latest, contracts: contracts)
    else
      render(conn, :error, code: 108, message: "size should not be greater than 10")
    end
  rescue
    _ -> render(conn, :error, code: 104, message: "invalid params")
  end

  def latest(conn, params) do
    latest(conn, Map.put(params, "size", "10"))
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
            render(conn, :error, code: 106, message: "#{inspect(error)}")
        end

      _otherwise ->
        render(conn, :error, code: 104, message: "invalid params")
    end
  end

  def sync(conn, %{"uuid" => _uuid, "network" => _network}) do
    render(conn, :error, code: 100, message: "unsupported")
  end

  def sync(conn, %{"uuid" => _uuid} = params) do
    sync(conn, Map.put(params, "network", "mainnet"))
  end
end
