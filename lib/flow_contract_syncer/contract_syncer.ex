defmodule FlowContractSyncer.ContractSyncer do
  @moduledoc false

  use Task
  import Ecto.Query

  require Logger

  alias FlowContractSyncer.{Client, Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, ContractEvent, Network}

  # 3s
  @interval 3000
  @chunk_size 20

  def start_link(%Network{name: name, id: id} = network) do
    Logger.info("[#{__MODULE__}_#{name}] started")
    {:ok, pid} = Task.start_link(__MODULE__, :contract_sync, [network])
    Process.register(pid, :"#{name}_#{id}_contract_syncer")
    {:ok, pid}
  end

  def contract_sync(%Network{} = network) do
    chunk_size = Network.contract_sync_chunk_size(network) || @chunk_size

    ContractEvent.unprocessed(network, chunk_size)
    |> Enum.each(fn event ->
      case sync_contract_from_event(network, event) do
        {:ok, _} ->
          ContractEvent.to_processed!(event)

        error ->
          Logger.error(
            "[#{__MODULE__}_#{network.name}] failed to sync contract for event: #{event.id}. error: #{inspect(error)}"
          )

          {:error, :sync_failed}
      end
    end)

    sync_interval = Network.contract_sync_interval(network) || @interval

    receive do
      :contract_sync -> contract_sync(network)
    after
      sync_interval -> contract_sync(network)
    end
  end

  def sync_contract_from_event(%Network{} = network, %ContractEvent{
        address: address,
        contract_name: name,
        type: type
      })
      when type in [:added, :updated, :removed] do
    status = get_status(type)
    sync_contract(network, address, name, status)
  end

  def sync_contract(%Network{} = network, address, name, status) do
    case get_contract_code(network, address, name) do
      {:ok, raw_code} ->
        uuid = Contract.create_uuid(address, name)
        # if the code is nil(maybe the contract is deleted?), we don't delete the old code data
        base =
          if is_nil(raw_code) do
            %Contract{network_id: network.id, uuid: uuid, address: address, name: name}
          else
            %Contract{
              network_id: network.id,
              uuid: uuid,
              code: raw_code,
              address: address,
              name: name
            }
          end

        insert_or_update_contract(base, status)

      error ->
        error
    end
  end

  defp get_status(type) when type in [:added, :updated], do: :normal
  defp get_status(:removed), do: :removed

  def insert_or_update_contract(
        %Contract{network_id: network_id, uuid: uuid, code: code} = contract,
        status
      )
      when status in [:normal, :removed] do
    old_contract =
      Contract
      |> where(network_id: ^network_id, uuid: ^uuid)
      |> Repo.one()

    remove_relationships =
      case old_contract do
        %Contract{} ->
          new_code_hash = Utils.calc_code_hash(code)
          old_contract.code_hash != new_code_hash

        nil ->
          false
      end

    item =
      case old_contract do
        %Contract{} -> old_contract
        nil -> contract
      end

    Repo.transaction(fn ->
      item
      |> Contract.changeset(%{
        code: code,
        deps_parsed: false,
        snippet_parsed: false,
        status: status
      })
      |> Repo.insert_or_update()
      |> case do
        {:ok, contract} ->
          if remove_relationships do
            Contract.remove_dependencies!(contract)
            Contract.remove_snippets!(contract)
          end

          contract

        error ->
          Logger.error(
            "[#{__MODULE__}_network_#{network_id}] insert contract failed, error: #{inspect(error)}"
          )

          Repo.rollback(:insert_contract_failed)
      end
    end)
  end

  def get_contract_code(%Network{} = network, address, name, opts \\ []) do
    script = get_contract_script()
    encoded_address = encode_address(address)
    encoded_name = encode_string(name)

    res =
      client_impl().execute_script(
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
         "type" => "Optional",
         "value" => nil
       }) do
    nil
  end

  defp do_decode_code(%{
         "type" => "Optional",
         "value" => %{
           "type" => "Array",
           "value" => encoded_bytes
         }
       })
       when is_list(encoded_bytes) do
    encoded_bytes
    |> Enum.map(fn
      %{"type" => "UInt8", "value" => value} -> String.to_integer(value)
    end)
    |> List.to_string()
  end

  defp get_contract_script do
    """
    pub fun main(address: Address, contractName: String): [UInt8]? {
      let account = getAccount(address)
      if let contract = account.contracts.get(name: contractName) {
          return contract.code
      }
      return nil
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

  defp client_impl do
    Application.get_env(:flow_contract_syncer, :client) || Client
  end
end
