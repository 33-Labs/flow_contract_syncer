defmodule FlowContractSyncer.DependencyParser do
  @moduledoc false

  use Task
  import Ecto.Query

  require Logger
  alias FlowContractSyncer.{ContractSyncer, Repo}
  alias FlowContractSyncer.Schema.{Contract, Dependency, Network}

  @interval 500
  @chunk_size 100

  def start_link(%Network{name: name, id: id} = network) do
    Logger.info("[#{__MODULE__}_#{name}] started")
    {:ok, pid} = Task.start_link(__MODULE__, :parse_deps, [network])
    Process.register(pid, :"#{name}_#{id}_dependency_parser")
    {:ok, pid}
  end

  def parse_deps(%Network{} = network) do
    chunk_size = Network.deps_parse_chunk_size(network) || @chunk_size

    Contract.deps_unparsed(network, chunk_size)
    |> Enum.each(fn contract ->
      case generate_deps(contract) do
        :ok ->
          Contract.to_deps_parsed!(contract)

        error ->
          Logger.error(
            "[#{__MODULE__}] failed to parse deps for contract: #{contract.id}. error: #{inspect(error)}"
          )

          {:error, :parse_failed}
      end
    end)

    sync_interval = Network.deps_parse_interval(network) || @interval

    receive do
      :parse_deps -> parse_deps(network)
    after
      sync_interval -> parse_deps(network)
    end
  end

  # NOTE:
  # If the dependency is not in the database, we need to fetch it from blockchain
  # In general, the contracts are synced in time order and this case will not happen, 
  # but we still need to handle this.
  # What if the contract has been removed? -> Then the contract code should be nil?
  def generate_deps(%Contract{id: contract_id} = contract) do
    contract = contract |> Repo.preload(:network)

    res =
      contract
      |> Contract.extract_imports()
      |> Enum.map(fn %{
                       "address" => address,
                       "contract" => contract_name
                     } ->
        uuid = Contract.create_uuid(address, contract_name)

        case Repo.get_by(Contract, uuid: uuid) do
          %Contract{id: dep_id} ->
            case insert_or_update_dep(contract_id, dep_id) do
              {:ok, _} -> :ok
              _otherwise -> :insert_failed
            end

          nil ->
            # just fetch the dep and don't mark this contract as parsed
            ContractSyncer.sync_contract(contract.network, address, contract_name, :normal)
            :add_new_contract
        end
      end)

    case Enum.all?(res, &(&1 == :ok)) do
      true -> :ok
      false -> {:error, :not_fullfilled}
    end
  end

  defp insert_or_update_dep(contract_id, dep_id) do
    Dependency
    |> where(contract_id: ^contract_id, dependency_id: ^dep_id)
    |> Repo.one()
    |> case do
      %Dependency{} = dep -> dep
      nil -> %Dependency{}
    end
    |> Dependency.changeset(%{contract_id: contract_id, dependency_id: dep_id})
    |> Repo.insert_or_update()
  end
end
