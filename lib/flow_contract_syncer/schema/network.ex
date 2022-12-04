defmodule FlowContractSyncer.Schema.Network do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "networks" do
    field :name, :string
    field :endpoint, :string
    field :min_sync_height, :integer
    field :config, :map
  end

  @required_fields ~w(name endpoint min_sync_height config)a
  def changeset(network, params \\ %{}) do
    network
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:name], name: :networks_name_index)
  end

  def contract_event_sync_chunk_size(%__MODULE__{config: config}) do
    config["contract_event_sync_chunk_size"]
  end

  def contract_event_sync_interval(%__MODULE__{config: config}) do
    config["contract_event_sync_interval"]
  end

  def contract_sync_chunk_size(%__MODULE__{config: config}) do
    config["contract_sync_chunk_size"]
  end

  def contract_sync_interval(%__MODULE__{config: config}) do
    config["contract_sync_interval"]
  end

  def deps_parse_chunk_size(%__MODULE__{config: config}) do
    config["deps_parse_chunk_size"]
  end

  def deps_parse_interval(%__MODULE__{config: config}) do
    config["deps_parse_interval"]
  end
end
