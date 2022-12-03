defmodule FlowContractSyncer.Schema.Contract do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias FlowContractSyncer.{Repo, Utils}
  alias FlowContractSyncer.Schema.{Dependency, Network}

  schema "contracts" do
    belongs_to :network, Network
    many_to_many :dependencies,
      __MODULE__,
      join_through: Dependency,
      join_keys: [contract_id: :id, dependency_id: :id]

    many_to_many :dependants,
      __MODULE__,
      join_through: Dependency,
      join_keys: [dependency_id: :id, contract_id: :id]

    field :uuid, :string
    field :address, :string
    field :name, :string
    field :status, Ecto.Enum, values: [normal: 0, removed: 1]
    field :code, :string
  
    timestamps()
  end

  @required_fields ~w(network_id uuid address name status code)a
  def changeset(struct, params \\ %{}) do
    params =
      case Map.get(params, :address) do
        nil -> 
          params
        address -> 
          Map.put(params, :address, Utils.normalize_address(address))
      end
    
    params =
      case Map.get(params, :uuid) do
        nil -> params
        uuid ->
          Map.put(params, :uuid, Utils.normalize_uuid(uuid))
      end

    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> validate_length(:address, is: 18)
    |> unique_constraint([:network_id, :uuid], name: :contracts_network_id_uuid_index)
  end

  def create_uuid(address, name) do
    "A.#{String.replace(address, "0x", "")}.#{name}"
  end

  def extract_imports(%__MODULE__{code: code}) do
    code
    |> remove_comments()
    |> do_extract_imports() 
  end

  # Should delete all the comments before run the regex
  # Or some unexisted contracts will be involved in
  # e.g. https://flow-view-source.com/mainnet/account/0x82eafacd9c87f83a/contract/Profile
  defp remove_comments(code) do
    regex = ~r/\/\*([\s\S]*?)\*\//

    Regex.replace(regex, code, "")
  end

  defp do_extract_imports(code) do
    regex = ~r/^ *import (?P<contracts>[A-Za-z_][A-Za-z0-9_]*( *, *[A-Za-z_][A-Za-z0-9_]+)*) *(from *(?P<address>0x[a-f0-9]+))?/

    code 
    |> String.split("\n")
    |> Enum.map(& Regex.named_captures(regex, &1))
    |> Enum.filter(& !is_nil(&1) and Map.get(&1, "address") != "") # import Crypto
    |> Enum.flat_map(fn %{
      "address" => address,
      "contracts" => contracts
    } ->
      # To handle special cases like 
      # import NonFungibleToken, MetadataViews from 0x1d7e57aa55817448
      contracts
      |> String.replace(" ", "")
      |> String.split(",")
      |> Enum.map(fn contract ->
        %{
          "address" => Utils.normalize_address(address),
          "contract" => contract
        }
      end)
    end)
  end

end