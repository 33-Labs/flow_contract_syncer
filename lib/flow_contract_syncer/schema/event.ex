defmodule FlowContractSyncer.Schema.Event do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.Network

  schema "events" do
    belongs_to :network, Network
    belongs_to :contract, Contract

    field :digest, :string
    field :block_height, :integer
    field :tx_id, :string
    field :tx_index, :integer
    field :type, Ecto.Enum, values: [added: 0, updated: 1, removed: 2]
    field :index, :integer
    field :address, :string
    field :code_hash, :string
    field :contract_name, :string
    field :processed, :boolean
  
    timestamps()
  end

  @required_fields ~w(digest block_height tx_id tx_index type index address code_hash contract_name processed)a
  def changeset(event, params \\ %{}) do
    event
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:network_id, :digest], name: :events_network_id_digest_index)
  end


  # %{
  #     "type" => "flow.AccountContractAdded",
  #     "transaction_id" => "341f1f480caf9bd1f693d753402193abae7327b778cf0291882b1c91a802be76",
  #     "transaction_index" => "0",
  #     "event_index" => "1",
  #     "payload" => "eyJ0eXBlIjoiRXZlbnQiLCJ2YWx1ZSI6eyJpZCI6ImZsb3cuQWNjb3VudENvbnRyYWN0QWRkZWQiLCJmaWVsZHMiOlt7Im5hbWUiOiJhZGRyZXNzIiwidmFsdWUiOnsidHlwZSI6IkFkZHJlc3MiLCJ2YWx1ZSI6IjB4MjVlYzhjY2U1NjZjNGNhNyJ9fSx7Im5hbWUiOiJjb2RlSGFzaCIsInZhbHVlIjp7InR5cGUiOiJBcnJheSIsInZhbHVlIjpbeyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExOCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxNzQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIzOSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI4MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTgwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjkwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjkxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIzMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyNTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiODUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjI1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIxOCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyMzEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjE2NSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjQ2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwNCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1OCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI0MSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxOTEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA2In1dfX0seyJuYW1lIjoiY29udHJhY3QiLCJ2YWx1ZSI6eyJ0eXBlIjoiU3RyaW5nIiwidmFsdWUiOiJMVVNEIn19XX19Cg=="
  # }
  def new(%{
    "type" => type,
    "transaction_id" => tx_id,
    "transaction_index" => raw_tx_index,
    "event_index" => raw_event_index,
    "payload" => payload
  } = event, block_height, %Network{id: network_id}) when type in [
    "flow.AccountContractAdded",
    "flow.AccountContractUpdated",
    "flow.AccountContractRemoved"
  ] and is_integer(block_height) do
    %{
      address: address,
      code_hash: code_hash,
      contract_name: contract_name
    } = decode_payload(payload)

    %__MODULE__{}
    |> changeset(%{
      network_id: network_id,
      digest: calc_event_digest(event, block_height),
      block_height: block_height,
      tx_id: tx_id,
      tx_index: String.to_integer(raw_tx_index),
      type: get_event_type(type),
      index: String.to_integer(raw_event_index),
      address: address,
      code_hash: code_hash,
      contract_name: contract_name,
      processed: false
    })
  end

  defp calc_event_digest(event, block_height) do
    event
    |> Map.put("block_height", block_height)
    |> Jason.encode!()
    |> (fn data -> :crypto.hash(:sha256, data) end).()
    |> Base.encode64()
  end

  defp get_event_type(type) do
    case type do
      "flow.AccountContractAdded" -> :added
      "flow.AccountContractUpdated" -> :updated
      "flow.AccountContractRemoved" -> :removed
    end
  end

  defp decode_payload(payload) do
    payload
    |> Base.decode64!()
    |> Jason.decode!()
    |> do_decode_payload()
  end

  defp do_decode_payload(%{
    "type" => "Event",
    "value" => %{
      "fields" => [
        %{
          "name" => "address",
          "value" => %{"type" => "Address", "value" => address}
        },
        %{
          "name" => "codeHash",
          "value" => %{
            "type" => "Array",
            "value" => encoded_bytes
          }
        },
        %{
          "name" => "contract",
          "value" => %{"type" => "String", "value" => contract_name}
        }
      ],
      "id" => _event_type
    }
  }) do
    code_hash =
      encoded_bytes
      |> Enum.map(fn
        %{"type" => "UInt8", "value" => value} -> String.to_integer(value)
      end)
      |> List.to_string() 
      |> Base.encode64()

    %{
      address: address,
      code_hash: code_hash,
      contract_name: contract_name
    }
  end
end