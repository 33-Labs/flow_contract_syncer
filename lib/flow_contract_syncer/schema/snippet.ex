defmodule FlowContractSyncer.Schema.Snippet do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias FlowContractSyncer.Schema.Contract
  alias FlowContractSyncer.{Repo, Utils}

  # No directly relationship with network or contract
  schema "snippets" do
    field :contract_code_hash, :string
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

  @required_fields ~w(contract_code_hash code_hash code type status)a
  def changeset(struct, params \\ %{}) do
    params =
      case Map.get(params, :code) do
        nil ->
          params

        code ->
          Map.put(params, :code_hash, Utils.calc_code_hash(code))
      end

    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:code_hash], name: :snippets_code_hash_index)
  end

  def extract_from_contract(%Contract{code: contract_code, code_hash: contract_code_hash}) do
    source = Contract.remove_comments(contract_code)

    resources = source |> get_resources() |> Enum.map(& {&1, :resource})
    resource_interfaces = source |> get_resource_interfaces |> Enum.map(& {&1, :resource_interface})
    structs = source |> get_structs() |> Enum.map(& {&1, :struct})
    struct_interfaces = source |> get_struct_interfaces() |> Enum.map(& {&1, :struct_interface})
    functions = source |> get_functions() |> Enum.map(& {&1, :function})
    events = source |> get_events() |> Enum.map(& {&1, :event})
    enums = source |> get_enums() |> Enum.map(& {&1, :enum})

    snippets = [resources, resource_interfaces, structs, struct_interfaces, functions, events, enums] |> List.flatten()

    Repo.transaction(fn ->
      snippets
      |> Enum.each(fn {code, type} ->
        # ignore the conflict
        %__MODULE__{}
        |> changeset(%{
          contract_code_hash: contract_code_hash,
          code: code,
          type: type,
          status: :normal
        })
        |> Repo.insert!(on_conflict: :nothing)
      end)
    end)
  end

  def get_resources(code) when is_binary(code) do
    regex = ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *resource *(?<name>(?!interface)[A-Za-z_][A-Za-z0-9_]*) *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m
    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_resource_interfaces(code) when is_binary(code) do
    regex = ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *resource *interface *(?<name>[A-Za-z_][A-Za-z0-9_]*) *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m
    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_structs(code) when is_binary(code) do
    regex = ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *struct *(?<name>(?!interface)[A-Za-z_][A-Za-z0-9_]*) *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m
    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_struct_interfaces(code) when is_binary(code) do
    regex = ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *struct *interface *(?<name>[A-Za-z_][A-Za-z0-9_]*) *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m
    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_functions(code) when is_binary(code) do
    regex = ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *fun *(?<name>[A-Za-z_][A-Za-z0-9_]*) *\([^()]*\)* *:?[^{}]+?(?<body>\{([^{}]*(?3)?)*+\})/m
    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_enums(code) when is_binary(code) do
    regex = ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *enum *(?<name>[A-Za-z_][A-Za-z0-9_]*) *: *(UInt|Int)[^{}]+?(?<body>\{([^{}]*(?4)?)*+\})/m
    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end

  def get_events(code) when is_binary(code) do
    regex = ~r/^ *(pub|priv|access\(self\)|access\(contract\)|access\(all\)|access\(account\)|pub\(set\))? *event *(?<name>[A-Za-z_][A-Za-z0-9_]*) *\([^()]*\)/m
    Regex.scan(regex, code)
    |> Enum.map(fn [hd | _] -> hd end)
  end
end
