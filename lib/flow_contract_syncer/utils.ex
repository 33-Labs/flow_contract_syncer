defmodule FlowContractSyncer.Utils do
  @moduledoc false

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.Contract

  def format_errors(errors) do
    Enum.reduce(errors, "", fn {key, value}, acc ->
      error = hd(value)
      acc <> "#{key}: #{error}\n"
    end)
  end

  def is_valid_uuid(uuid) do
    normalize_uuid(uuid)
    true
  rescue
    _ -> false
  end

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
