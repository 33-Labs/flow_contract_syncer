defmodule FlowContractSyncer.Utils do
  @moduledoc false

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.Contract

  def normalize_address(address) do
    if String.length(address) != 18 do
      String.replace(address, "0x", "0x0")
    else
      address 
    end
  end

  def normalize_uuid(uuid) do
    ["A", raw_address, contract_name] = String.split(uuid, ".")
    
    address =
      if String.length(raw_address) == 15 do
        "0#{raw_address}"
      else
        raw_address
      end

    "A.#{address}.#{contract_name}"
  end

  def normalize_contracts do
    Contract
    |> Repo.all()
    |> Enum.each(fn contract ->
      contract
      |> Contract.changeset(%{
        address: contract.address,
        uuid: contract.uuid
      })
      |> Repo.update!()
    end)
  end

end