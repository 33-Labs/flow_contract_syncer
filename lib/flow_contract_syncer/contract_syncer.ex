defmodule FlowContractSyncer.ContractSyncer do
  @moduledoc false

  alias FlowContractSyncer.Client

  def get_contract(address, name, opts \\ []) do
    script = get_contract_script()
    encoded_address = encode_address(address)
    encoded_name = encode_string(name)

    res = Client.execute_script(
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
    %{"type" => "Address", "value" => address}
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp encode_string(value) when is_binary(value) do
    %{"type" => "String", "value" => value}
    |> Jason.encode!()
    |> Base.encode64()
  end
end