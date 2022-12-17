defmodule FlowContractSyncer.Schema.Contract do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}

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
    field :parsed, :boolean

    timestamps()
  end

  @required_fields ~w(network_id uuid address name status parsed)a
  @optional_fields ~w(code)a
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
        nil ->
          params

        uuid ->
          Map.put(params, :uuid, Utils.normalize_uuid(uuid))
      end

    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:address, is: 18)
    |> unique_constraint([:network_id, :uuid], name: :contracts_network_id_uuid_index)
  end

  def code_without_imports(code) do
  end

  def create_uuid(address, name) do
    "A.#{String.replace(address, "0x", "")}.#{name}"
  end

  def total_amount(%Network{id: network_id}) do
    Repo.one(from c in __MODULE__, where: c.network_id == ^network_id, select: count("*"))
  end

  def with_deps_uuids(%__MODULE__{} = contract) do
    dependants_query = 
      from c in __MODULE__, 
        join: d in Dependency,
        on: d.dependency_id == ^contract.id and c.id == d.contract_id,
        select: c.uuid
    
    dependencies_query =
      from c in __MODULE__,
        join: d in Dependency, 
        on: d.contract_id == ^contract.id and c.id == d.dependency_id,
        select: c.uuid

    Repo.preload(contract, [
        dependencies: dependencies_query,
        dependants: dependants_query
      ]
    )
  end

  def sort_by_inserted_at(%Network{id: network_id}, sort_by, size)
    when is_integer(size) and sort_by in ["asc", "desc"] do
    direction = String.to_atom(sort_by)
    dependants = group_by_dependants()
    dependencies = group_by_dependencies()

    query =
      from c in __MODULE__,
        left_join: d in subquery(dependants),
        on: d.dependency_id == c.id,
        left_join: dd in subquery(dependencies),
        on: dd.contract_id == c.id,
        where: c.network_id == ^network_id,
        order_by: [{^direction, c.inserted_at}],
        limit: ^size,
        select: %{
          uuid: c.uuid,
          dependants_count: coalesce(d.count, 0),
          dependencies_count: coalesce(dd.count, 0)
        }

    Repo.all(query)
  end

  def sort_by_dependants(%Network{id: network_id}, sort_by, size)
      when is_integer(size) and sort_by in ["asc", "desc"] do
      direction = 
        case sort_by do
          "asc" -> :asc_nulls_first
          "desc" -> :desc_nulls_last
        end
    dependants = group_by_dependants()
    dependencies = group_by_dependencies()

    query =
      from c in __MODULE__,
        left_join: d in subquery(dependants),
        on: d.dependency_id == c.id,
        left_join: dd in subquery(dependencies),
        on: dd.contract_id == c.id,
        where: c.network_id == ^network_id,
        order_by: [{^direction, coalesce(d.count, 0)}],
        limit: ^size,
        select: %{
          uuid: c.uuid,
          dependants_count: coalesce(d.count, 0),
          dependencies_count: coalesce(dd.count, 0)
        }

    Repo.all(query)
  end

  def sort_by_dependencies(%Network{id: network_id}, sort_by, size)
      when is_integer(size) and sort_by in ["asc", "desc"] do
    direction = 
      case sort_by do
        "asc" -> :asc_nulls_first
        "desc" -> :desc_nulls_last
      end
    dependants = group_by_dependants()
    dependencies = group_by_dependencies()

    query =
      from c in __MODULE__,
        left_join: d in subquery(dependencies),
        on: d.contract_id == c.id,
        left_join: dd in subquery(dependants),
        on: dd.dependency_id == c.id,
        where: c.network_id == ^network_id,
        order_by: [{^direction, coalesce(d.count, 0)}],
        limit: ^size,
        select: %{
          uuid: c.uuid,
          dependants_count: coalesce(dd.count, 0),
          dependencies_count: coalesce(d.count, 0)
        }

    Repo.all(query)
  end

  def unparsed(%Network{id: network_id}, limit \\ 100) do
    __MODULE__
    |> where(network_id: ^network_id, parsed: false)
    |> order_by(asc: :id)
    |> limit(^limit)
    |> Repo.all()
  end

  def to_parsed!(%__MODULE__{} = contract) do
    contract
    |> changeset(%{parsed: true})
    |> Repo.update!()
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
    regex =
      ~r/^ *import (?P<contracts>[A-Za-z_][A-Za-z0-9_]*( *, *[A-Za-z_][A-Za-z0-9_]+)*) *(from *(?P<address>0x[a-f0-9]+))?/

    code
    |> String.split("\n")
    |> Enum.map(&Regex.named_captures(regex, &1))
    # import Crypto
    |> Enum.filter(&(!is_nil(&1) and Map.get(&1, "address") != ""))
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

  defp group_by_dependants do
    from d in Dependency,
      group_by: d.dependency_id,
      select: %{dependency_id: d.dependency_id, count: count(d.id)}
  end

  defp group_by_dependencies do
    from d in Dependency,
      group_by: d.contract_id,
      select: %{contract_id: d.contract_id, count: count(d.id)}
  end
end
