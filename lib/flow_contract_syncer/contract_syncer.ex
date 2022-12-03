defmodule FlowContractSyncer.ContractSyncer do
  @moduledoc false

  use Task
  import Ecto.Query

  require Logger

  alias FlowContractSyncer.{Client, Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, ContractEvent, Dependency, Network, NetworkState}

  # 100ms
  @interval 100
  @chunk_size 250
  @timeout 5000

  @added_event "flow.AccountContractAdded"
  @updated_event "flow.AccountContractUpdated"
  @removed_event "flow.AccountContractRemoved"

  def start_link(%Network{name: name, id: id} = network) do
    {:ok, pid} = Task.start_link(__MODULE__, :contract_sync, [network])
    Process.register(pid, :"#{name}_#{id}_contract_syncer")
    {:ok, pid}
  end

  def contract_sync(%Network{} = network) do
    ContractEvent.unprocessed()
    |> Enum.each(fn event ->
      case sync_contract_from_event(network, event) do
        {:ok, _} -> ContractEvent.to_processed!(event)
        error ->
          Logger.error("[#{__MODULE__}__] failed to sync contract for event: #{event.id}. error: #{inspect(error)}")
          {:error, :sync_failed}
      end
    end)
  end

  def sync_contract_from_event(%Network{} = network, %ContractEvent{
    address: address,
    contract_name: name,
    type: type
  }) when type in [:added, :updated, :removed] do
    case get_contract_code(network, address, name) do
      {:ok, code} ->
        uuid = Contract.create_uuid(address, name)
        insert_or_update_contract(
          %Contract{network_id: network.id, uuid: uuid, code: code},
          get_status(type)
        )
      error ->
        error 
    end
  end

  defp get_status(type) when type in [:added, :updated], do: :normal
  defp get_status(:removed), do: :removed

  def insert_or_update_contract(
    %Contract{network_id: network_id, uuid: uuid, code: code} = contract,
    status
  ) when code != "" and status in [:normal, :removed] do
    Contract
    |> where(network_id: ^network_id, uuid: ^uuid)
    |> Repo.one()
    |> case do
      %Contract{} = old_contract -> old_contract
      nil -> contract
    end
    |> Contract.changeset(%{
      code: code,
      status: status
    })
    |> Repo.insert_or_update()
  end





  def sync_and_create_contract(%Network{id: network_id} = network, address, name) do
    case get_contract_code(network, address, name) do
      {:ok, code} ->
        uuid = "A.#{String.replace(address, "0x", "")}.#{name}"
        %Contract{}
        |> Contract.changeset(%{
          network_id: network_id,
          uuid: uuid,
          address: address,
          name: name,
          status: :normal,
          code: code
        })
        |> Repo.insert()
      error ->
        Logger.error(error)
        error
    end
  end

  def generate_all_dependencies do
    Contract
    |> Repo.all()
    |> Enum.each(fn contract ->
      generate_dependencies(contract)
    end)
  end

  def generate_dependencies(%Contract{id: contract_id} = contract) do
    contract = contract |> Repo.preload(:network)

    contract
    |> Contract.extract_imports()
    |> Enum.map(fn %{
      "address" => "0x" <> raw_address = address, 
      "contract" => contract_name
    } ->
      uuid = "A.#{raw_address}.#{contract_name}"
      case Repo.get_by(Contract, uuid: uuid) do
        %Contract{id: dependency_id} ->
          # It might be existed, we just insert it and ignore the errors.
          %Dependency{}
          |> Dependency.changeset(%{
            contract_id: contract_id,
            dependency_id: dependency_id
          })
          |> Repo.insert()

        nil ->
          # If the dependency is not in the database, we need to fetch it from blockchain
          # In general, the contracts are synced in time order and this case will not happen, 
          # but we still need to handle this.
          # What if the contract has been removed? 
          # -> Then the contract code should be empty?
          IO.inspect "address: #{address} contract_name: #{contract_name}"
          case sync_and_create_contract(contract.network, address, contract_name) do
            {:ok, %Contract{id: dependency_id}} ->
              %Dependency{}
              |> Dependency.changeset(%{
                contract_id: contract_id,
                dependency_id: dependency_id
              })
              |> Repo.insert()

            _otherwise ->
              nil
          end
        end
    end)
  end

  def get_contract_code(%Network{} = network, address, name, opts \\ []) do
    script = get_contract_script()
    encoded_address = encode_address(address)
    encoded_name = encode_string(name)

    res = Client.execute_script(
      network,
      script,
      [encoded_address, encoded_name], 
      opts
    )

    case res do
      {:ok, encoded_code} -> {:ok, decode_code(encoded_code)}
      error -> error
    end
  end

  defp decode_code(code) do
    code
    |> Base.decode64!()
    |> Jason.decode!()
    |> do_decode_code()
  end

  defp do_decode_code(%{
    "type" => "Array",
    "value" => encoded_bytes
  }) when is_list(encoded_bytes) do
    encoded_bytes
    |> Enum.map(fn
      %{"type" => "UInt8", "value" => value} -> String.to_integer(value)
    end)
    |> List.to_string()
  end

  defp get_contract_script do
    """
    pub fun main(address: Address, contractName: String): [UInt8] {
      let account = getAccount(address)
      if let contract = account.contracts.get(name: contractName) {
          return contract.code
      }
      return []
    }
    """
    |> Base.encode64()
  end

  defp encode_address(address) when is_binary(address) do
    # SEE: https://flow-view-source.com/mainnet/account/0x50b286b60012753/contract/REVV

    %{"type" => "Address", "value" => Utils.normalize_address(address)}
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp encode_string(value) when is_binary(value) do
    %{"type" => "String", "value" => value}
    |> Jason.encode!()
    |> Base.encode64()
  end
end