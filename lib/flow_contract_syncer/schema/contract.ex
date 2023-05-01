defmodule FlowContractSyncer.Schema.Contract do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias FlowContractSyncer.{Repo, Utils}
  alias FlowContractSyncer.Schema.{ContractEvent, ContractSnippet, Dependency, Network, Snippet}

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

    many_to_many :snippets, Snippet, join_through: ContractSnippet

    field :uuid, :string
    field :address, :string
    field :name, :string
    field :status, Ecto.Enum, values: [normal: 0, removed: 1]
    field :code, :string
    field :code_hash, :string
    field :deps_parsed, :boolean
    field :snippet_parsed, :boolean

    timestamps()
  end

  @required_fields ~w(network_id uuid address name status deps_parsed snippet_parsed)a
  @optional_fields ~w(code_hash code)a
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

    params =
      case Map.get(params, :code) do
        nil ->
          params

        code ->
          Map.put(params, :code_hash, Utils.calc_code_hash(code))
      end

    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:address, is: 18)
    |> unique_constraint([:network_id, :uuid], name: :contracts_network_id_uuid_index)
  end

  def events(%__MODULE__{network_id: network_id, address: address, name: name}) do
    ContractEvent
    |> where(network_id: ^network_id, address: ^address, contract_name: ^name)
    |> order_by(asc: :block_height, asc: :tx_index, asc: :index)
    |> select([:tx_id, :block_height, :type, :block_timestamp])
    |> Repo.all()
    |> Enum.map(fn data ->
      %{
        tx_id: data.tx_id,
        block_height: data.block_height,
        block_timestamp: data.block_timestamp,
        type: data.type
      }
    end)
  end

  def dependencies(
        %__MODULE__{id: contract_id, network_id: network_id},
        :dependants_count,
        direction,
        offset,
        limit
      )
      when is_integer(offset) and is_integer(limit) do
    direction = String.to_atom(direction)
    dependants = group_by_dependants()

    query =
      from c in __MODULE__,
        left_join: d in subquery(dependants),
        on: d.dependency_id == c.id,
        join: ddd in Dependency,
        on: c.id == ddd.dependency_id and ddd.contract_id == ^contract_id,
        where: c.network_id == ^network_id,
        order_by: [{^direction, coalesce(d.count, 0)}],
        offset: ^offset,
        limit: ^limit,
        select: %{uuid: c.uuid}

    query |> Repo.all() |> Enum.map(& &1.uuid)
  end

  def dependencies(%__MODULE__{id: contract_id}, order_by, direction, offset, limit)
      when is_integer(offset) and is_integer(limit) and order_by in [:name, :address] do
    direction = String.to_atom(direction)
    order = [{direction, order_by}]

    __MODULE__
    |> join(:inner, [c], d in Dependency, on: d.contract_id == ^contract_id)
    |> where([c, d], d.dependency_id == c.id)
    |> order_by(^order)
    |> offset(^offset)
    |> limit(^limit)
    |> select([:uuid])
    |> Repo.all()
    |> Enum.map(& &1.uuid)
  end

  def dependants(
        %__MODULE__{id: contract_id, network_id: network_id},
        :dependants_count,
        direction,
        offset,
        limit
      )
      when is_integer(offset) and is_integer(limit) do
    direction = String.to_atom(direction)
    dependants = group_by_dependants()

    query =
      from c in __MODULE__,
        left_join: d in subquery(dependants),
        on: d.dependency_id == c.id,
        join: ddd in Dependency,
        on: c.id == ddd.contract_id and ddd.dependency_id == ^contract_id,
        where: c.network_id == ^network_id,
        order_by: [{^direction, coalesce(d.count, 0)}],
        offset: ^offset,
        limit: ^limit,
        select: %{uuid: c.uuid}

    query |> Repo.all() |> Enum.map(& &1.uuid)
  end

  def dependants(%__MODULE__{id: contract_id}, order_by, direction, offset, limit)
      when is_integer(offset) and is_integer(limit) and order_by in [:name, :address] do
    direction = String.to_atom(direction)
    order = [{direction, order_by}]

    __MODULE__
    |> join(:inner, [c], d in Dependency, on: d.dependency_id == ^contract_id)
    |> where([c, d], d.contract_id == c.id)
    |> order_by(^order)
    |> offset(^offset)
    |> limit(^limit)
    |> select([:uuid])
    |> Repo.all()
    |> Enum.map(& &1.uuid)
  end

  def snippets(%__MODULE__{id: contract_id}, types) do
    contracts =
      from cs in ContractSnippet,
        group_by: cs.snippet_id,
        select: %{snippet_id: cs.snippet_id, count: count(cs.id)}

    query =
      from s in Snippet,
        left_join: cs in subquery(contracts),
        on: cs.snippet_id == s.id,
        join: ccs in ContractSnippet,
        on: ccs.contract_id == ^contract_id and ccs.snippet_id == cs.snippet_id,
        order_by: [desc: coalesce(cs.count, 0)],
        select: %{
          code_hash: s.code_hash,
          code: s.code,
          type: s.type,
          contracts_count: coalesce(cs.count, 0)
        }

    query =
      case types do
        [:all] -> query
        types -> query |> where([s, _cs], s.type in ^types)
      end

    query |> Repo.all()
  end

  def remove_dependencies!(%__MODULE__{id: contract_id} = contract) do
    {:ok, _} =
      Repo.transaction(fn ->
        Dependency
        |> where(contract_id: ^contract_id)
        |> Repo.delete_all()

        contract
        |> changeset(%{deps_parsed: false})
        |> Repo.update!()
      end)
  end

  def remove_snippets!(%__MODULE__{id: contract_id} = contract) do
    {:ok, _} =
      Repo.transaction(fn ->
        ContractSnippet
        |> where(contract_id: ^contract_id)
        |> Repo.delete_all()

        contract
        |> changeset(%{snippet_parsed: false})
        |> Repo.update!()
      end)
  end

  def create_uuid(address, name) do
    "A.#{String.replace(address, "0x", "")}.#{name}"
  end

  def total_amount(%Network{id: network_id}) do
    Repo.one(
      from c in __MODULE__,
        where: c.network_id == ^network_id and c.status == :normal,
        select: count("*")
    )
  end

  def dependants_count(%__MODULE__{} = contract) do
    from(d in Dependency, where: d.dependency_id == ^contract.id, select: count(d.id))
    |> Repo.one()
  end

  def dependencies_count(%__MODULE__{} = contract) do
    from(d in Dependency, where: d.contract_id == ^contract.id, select: count(d.id))
    |> Repo.one()
  end

  def use_snippet(%Snippet{id: snippet_id}, offset, limit) do
    dependants = group_by_dependants()
    dependencies = group_by_dependencies()

    query =
      from c in __MODULE__,
        left_join: d in subquery(dependants),
        on: d.dependency_id == c.id,
        left_join: dd in subquery(dependencies),
        on: dd.contract_id == c.id,
        join: cs in ContractSnippet,
        on: c.id == cs.contract_id and cs.snippet_id == ^snippet_id

    count =
      from(c in query, select: count(c.id))
      |> Repo.one()

    query =
      from [c, d, dd, _cs] in query,
        order_by: [desc: coalesce(d.count, 0)],
        offset: ^offset,
        limit: ^limit,
        select: %{
          uuid: c.uuid,
          dependants_count: coalesce(d.count, 0),
          dependencies_count: coalesce(dd.count, 0)
        }

    %{count: count, contracts: Repo.all(query)}
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

    Repo.preload(contract,
      dependencies: dependencies_query,
      dependants: dependants_query
    )
  end

  def search(%Network{id: network_id}, keyword, scope, offset, limit)
      when is_binary(keyword) and
             scope in [
               "uuid",
               "code",
               "uuid,code",
               "code,uuid"
             ] and is_integer(offset) and is_integer(limit) do
    dependants = group_by_dependants()
    dependencies = group_by_dependencies()

    search_term = "%#{keyword}%"

    query =
      from c in __MODULE__,
        left_join: d in subquery(dependants),
        on: d.dependency_id == c.id,
        left_join: dd in subquery(dependencies),
        on: dd.contract_id == c.id

    query =
      case scope do
        "uuid" ->
          from c in query, where: c.network_id == ^network_id and ilike(c.uuid, ^search_term)

        "code" ->
          from c in query, where: c.network_id == ^network_id and ilike(c.code, ^search_term)

        s when s in ["uuid,code", "code,uuid"] ->
          from c in query,
            where:
              c.network_id == ^network_id and
                (ilike(c.code, ^search_term) or ilike(c.uuid, ^search_term))
      end

    count =
      from(c in query, select: count(c.id))
      |> Repo.one()

    query =
      from [c, d, dd] in query,
        order_by: [desc: coalesce(d.count, 0)],
        offset: ^offset,
        limit: ^limit,
        select: %{
          uuid: c.uuid,
          dependants_count: coalesce(d.count, 0),
          dependencies_count: coalesce(dd.count, 0)
        }

    %{count: count, contracts: Repo.all(query)}
  end

  def order_by(:inserted_at, %Network{id: network_id}, owner, direction, offset, limit)
      when is_integer(offset) and is_integer(limit) and direction in ["asc", "desc"] do
    direction = String.to_atom(direction)
    dependants = group_by_dependants()
    dependencies = group_by_dependencies()

    query =
      from c in __MODULE__,
        left_join: d in subquery(dependants),
        on: d.dependency_id == c.id,
        left_join: dd in subquery(dependencies),
        on: dd.contract_id == c.id,
        where: c.network_id == ^network_id

    query = filter_by_owner(query, owner)

    count =
      from(c in query, select: count(c.id))
      |> Repo.one()

    contracts =
      from [c, d, dd] in query,
        order_by: [{^direction, c.inserted_at}],
        offset: ^offset,
        limit: ^limit,
        select: %{
          uuid: c.uuid,
          dependants_count: coalesce(d.count, 0),
          dependencies_count: coalesce(dd.count, 0)
        }

    result = contracts |> Repo.all()
    %{count: count, contracts: result}
  end

  def order_by(:dependants_count, %Network{id: network_id}, owner, direction, offset, limit)
      when is_integer(offset) and is_integer(limit) and direction in ["asc", "desc"] do
    direction =
      case direction do
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
        where: c.network_id == ^network_id

    query = filter_by_owner(query, owner)

    count =
      from(c in query, select: count(c.id))
      |> Repo.one()

    contracts =
      from [c, d, dd] in query,
        order_by: [{^direction, coalesce(d.count, 0)}],
        offset: ^offset,
        limit: ^limit,
        select: %{
          uuid: c.uuid,
          dependants_count: coalesce(d.count, 0),
          dependencies_count: coalesce(dd.count, 0)
        }

    result = contracts |> Repo.all()
    %{count: count, contracts: result}
  end

  def order_by(:dependencies_count, %Network{id: network_id}, owner, direction, offset, limit)
      when is_integer(offset) and is_integer(limit) and direction in ["asc", "desc"] do
    direction =
      case direction do
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
        where: c.network_id == ^network_id

    query = filter_by_owner(query, owner)

    count =
      from(c in query, select: count(c.id))
      |> Repo.one()

    contracts =
      from [c, d, dd] in query,
        order_by: [{^direction, coalesce(d.count, 0)}],
        offset: ^offset,
        limit: ^limit,
        select: %{
          uuid: c.uuid,
          dependants_count: coalesce(dd.count, 0),
          dependencies_count: coalesce(d.count, 0)
        }

    result = contracts |> Repo.all()
    %{count: count, contracts: result}
  end

  def extract_snippets(%__MODULE__{code: contract_code}) do
    import Snippet,
      only: [
        get_resources: 1,
        get_resource_interfaces: 1,
        get_structs: 1,
        get_struct_interfaces: 1,
        get_functions_with_return: 1,
        get_functions_without_return: 1,
        get_enums: 1,
        get_events: 1
      ]

    source = remove_comments(contract_code)

    resources = source |> get_resources() |> Enum.map(&{&1, :resource})

    resource_interfaces =
      source |> get_resource_interfaces |> Enum.map(&{&1, :resource_interface})

    structs = source |> get_structs() |> Enum.map(&{&1, :struct})
    struct_interfaces = source |> get_struct_interfaces() |> Enum.map(&{&1, :struct_interface})
    functions_with_return = source |> get_functions_with_return() |> Enum.map(&{&1, :function})

    functions_without_return =
      source |> get_functions_without_return() |> Enum.map(&{&1, :function})

    events = source |> get_events() |> Enum.map(&{&1, :event})
    enums = source |> get_enums() |> Enum.map(&{&1, :enum})

    [
      resources,
      resource_interfaces,
      structs,
      struct_interfaces,
      functions_with_return,
      functions_without_return,
      events,
      enums
    ]
    |> List.flatten()
  end

  def deps_unparsed(%Network{id: network_id}, limit \\ 100) do
    __MODULE__
    |> where(network_id: ^network_id, deps_parsed: false)
    |> order_by(asc: :id)
    |> limit(^limit)
    |> Repo.all()
  end

  def to_deps_parsed!(%__MODULE__{} = contract) do
    contract
    |> changeset(%{deps_parsed: true})
    |> Repo.update!()
  end

  def snippet_unparsed(%Network{id: network_id}, limit \\ 100) do
    __MODULE__
    |> where(network_id: ^network_id, snippet_parsed: false)
    |> order_by(asc: :id)
    |> limit(^limit)
    |> Repo.all()
  end

  def to_snippet_parsed!(%__MODULE__{} = contract) do
    contract
    |> changeset(%{snippet_parsed: true})
    |> Repo.update!()
  end

  def extract_events(%__MODULE__{uuid: uuid, code: code}) do
    code
    |> remove_comments()
    |> do_extract_events()
    |> Enum.map(&"#{uuid}.#{&1}")
  end

  # public only
  defp do_extract_events(code) do
    # regex = ~r/^ *pub? event [A-Za-z_][A-Za-z0-9_]*\(.*?\)/sm
    regex = ~r/^ *pub? event (?P<event_name>[A-Za-z_][A-Za-z0-9_]*)\(/m

    Regex.scan(regex, code)
    |> Enum.map(fn
      [_, name] -> name
      _otherwise -> nil
    end)
    |> Enum.reject(&is_nil(&1))
  end

  def extract_imports(%__MODULE__{code: code}) do
    code
    |> remove_comments()
    |> do_extract_imports()
  end

  # Should delete all the comments before run the regex
  # Or some unexisted contracts will be involved in
  # e.g. https://flow-view-source.com/mainnet/account/0x82eafacd9c87f83a/contract/Profile
  def remove_comments(nil) do
    nil
  end

  def remove_comments(code) do
    regex = ~r/\/\*([\s\S]*?)\*\//

    Regex.replace(regex, code, "")
  end

  defp do_extract_imports(nil) do
    []
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

  defp filter_by_owner(query, nil) do
    query
  end

  defp filter_by_owner(query, owner) do
    from c in query, where: c.address == ^owner
  end
end
