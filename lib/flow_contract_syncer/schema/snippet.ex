defmodule FlowContractSyncer.Schema.Snippet do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias FlowContractSyncer.Schema.{ContractSnippet, Network}
  alias FlowContractSyncer.{Repo, Utils}

  # No directly relationship with network or contract
  schema "snippets" do
    belongs_to :network, Network

    field :code_hash, :string
    field :code, :string

    field :type, Ecto.Enum,
      values: [
        resource: 0,
        struct: 1,
        resource_interface: 2,
        struct_interface: 3,
        function: 4,
        enum: 5,
        event: 6
      ]

    # if the source contract removed, the snippets should be removed too
    # to make sure unsecure code would be not searched by other
    field :status, Ecto.Enum,
      values: [
        normal: 0,
        removed: 1
      ]

    timestamps()
  end

  @required_fields ~w(network_id code_hash code type status)a
  def changeset(struct, params \\ %{}) do
    params =
      case Map.get(params, :code) do
        nil ->
          params

        code ->
          params
          |> Map.put(:code, format_code(code))
          |> Map.put(:code_hash, Utils.calc_code_hash(code))
      end

    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:code_hash, :network_id], name: :snippets_code_hash_network_id_index)
  end

  def normal(%Network{id: network_id}, size \\ 100) do
    __MODULE__
    |> where(network_id: ^network_id, status: :normal)
    |> limit(^size)
    |> Repo.all()
  end

  def to_removed(%__MODULE__{} = struct) do
    struct
    |> changeset(%{status: :removed})
    |> Repo.update()
  end

  def contracts_count(%__MODULE__{id: snippet_id}) do
    from(cs in ContractSnippet, where: cs.snippet_id == ^snippet_id, select: count(cs.id))
    |> Repo.one()
  end

  @valid_types ["resource", "struct", "interface", "function", "enum", "event", "all"]
  def search(%Network{id: network_id}, keyword, type, offset, limit)
      when is_binary(keyword) and type in @valid_types and
             is_integer(offset) and is_integer(limit) do
    types =
      case type do
        "interface" -> [:resource_interface, :struct_interface]
        otherwise -> [String.to_atom(otherwise)]
      end

    search_term = "%#{keyword}%"

    contracts =
      from cs in ContractSnippet,
        group_by: cs.snippet_id,
        select: %{snippet_id: cs.snippet_id, count: count(cs.id)}

    query =
      from s in __MODULE__,
        left_join: cs in subquery(contracts),
        on: cs.snippet_id == s.id,
        where: s.network_id == ^network_id and ilike(s.code, ^search_term),
        order_by: [desc: coalesce(cs.count, 0)],
        offset: ^offset,
        limit: ^limit,
        select: %{
          code_hash: s.code_hash,
          code: s.code,
          type: s.type,
          contracts_count: coalesce(cs.count, 0)
        }

    query =
      case types do
        [:all] -> query
        types -> from s in query, where: s.type in ^types
      end

    query |> Repo.all()
  end

  def get_resources(code) when is_binary(code) do
    regex =
      ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *resource *(?<name>(?!interface)[A-Za-z_][A-Za-z0-9_]*) *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m

    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_resource_interfaces(code) when is_binary(code) do
    regex =
      ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *resource *interface *(?<name>[A-Za-z_][A-Za-z0-9_]*) *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m

    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_structs(code) when is_binary(code) do
    regex =
      ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *struct *(?<name>(?!interface)[A-Za-z_][A-Za-z0-9_]*) *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m

    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_struct_interfaces(code) when is_binary(code) do
    regex =
      ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *struct *interface *(?<name>[A-Za-z_][A-Za-z0-9_]*) *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m

    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_functions_with_return(code) when is_binary(code) do
    regex =
      ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? fun (?<name>[A-Za-z_][A-Za-z0-9_]*)\([^()]*\) *: *([A-Z\[\{\&\@][A-Za-z0-9_.\[\]\{\}\: \&\@]+[A-Za-z0-9_\]\}])(\{[A-Za-z0-9\ \,\.]*\})?\??[\ \n]*(?<body>\{([^{}]*(?5)?)*+\})/m

    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
    |> Enum.reject(&(!String.contains?(&1, "return ")))
  end

  def get_functions_without_return(code) when is_binary(code) do
    regex =
      ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *fun *(?<name>[A-Za-z_][A-Za-z0-9_]*) *\([^()]*\) *(?<body>\{([^{}]*(?3)?)*+\})/m

    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_enums(code) when is_binary(code) do
    regex =
      ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *enum *(?<name>[A-Za-z_][A-Za-z0-9_]*) *: *(UInt|Int)[^{}]+?(?<body>\{([^{}]*(?4)?)*+\})/m

    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_events(code) when is_binary(code) do
    regex =
      ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *event *(?<name>[A-Za-z_][A-Za-z0-9_]*) *\([^()]*\)/m

    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  defp format_code(code) do
    lines = code |> String.split("\n") |> Enum.reject(&(String.length(&1) == 0))

    case lines do
      [first | _rest] ->
        w_count = get_leading_whitespaces_count(first)

        lines
        |> Enum.map(fn line ->
          if get_leading_whitespaces_count(line) >= w_count do
            String.slice(line, w_count, String.length(line))
          else
            line
          end
        end)
        |> Enum.join("\n")

      _ ->
        code
    end
  end

  defp get_leading_whitespaces_count(line) do
    do_get_leading_whitespaces_count(line, 0)
  end

  defp do_get_leading_whitespaces_count(" " <> rest, count) do
    do_get_leading_whitespaces_count(rest, count + 1)
  end

  defp do_get_leading_whitespaces_count(_rest, count) do
    count
  end
end
