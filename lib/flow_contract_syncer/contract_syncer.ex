defmodule FlowContractSyncer.ContractSyncer do
  @moduledoc false

  require Logger

  alias FlowContractSyncer.{Client, Repo, Utils}
  alias FlowContractSyncer.Schema.{Contract, Dependency, Network}

  def sync_contract(%Network{id: network_id} = network, address, name) do
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
          case sync_contract(contract.network, address, contract_name) do
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