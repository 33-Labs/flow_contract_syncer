defmodule FlowContractSyncer.ContractEventCase do
  alias FlowContractSyncer.Schema.Network
  alias FlowContractSyncer.Repo

  def create_network(_context) do
    network =
      %Network{}
      |> Network.changeset(%{
        name: "test",
        endpoint: "https://rest-mainnet.onflow.org/v1",
        min_sync_height: 0,
        config: %{
          "contract_event_sync_interval" => 5000,
          "contract_event_sync_chunk_size" => 10,
          "contract_sync_interval" => 5000,
          "contract_sync_chunk_size" => 10,
          "deps_parse_interval" => 5000,
          "deps_parse_chunk_size" => 10
        }
      })
      |> Repo.insert!()

    [network: network]
  end

  def generate_events(_context) do
    added_events = [
      %{
        "block_id" => "5baa81b99de13e4b4e22080a88aeec3e7aef51fe80aad9f6a5017c40d224e6c9",
        "block_height" => "5",
        "block_timestamp" => "2022-11-29T03:57:00.842612413Z",
        "events" => [
          %{
            "type" => "flow.AccountContractAdded",
            "transaction_id" =>
              "341f1f480caf9bd1f693d753402193abae7327b778cf0291882b1c91a802be76",
            "transaction_index" => "0",
            "event_index" => "1",
            "payload" =>
              "eyJ0eXBlIjoiRXZlbnQiLCJ2YWx1ZSI6eyJpZCI6ImZsb3cuQWNjb3VudENvbnRyYWN0QWRkZWQiLCJmaWVsZHMiOlt7Im5hbWUiOiJhZGRyZXNzIiwidmFsdWUiOnsidHlwZSI6IkFkZHJlc3MiLCJ2YWx1ZSI6IjB4MjVlYzhjY2U1NjZjNGNhNyJ9fSx7Im5hbWUiOiJjb2RlSGFzaCIsInZhbHVlIjp7InR5cGUiOiJBcnJheSIsInZhbHVlIjpbeyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExOCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxNzQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIzOSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI4MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTgwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjkwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjkxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIzMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyNTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiODUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjI1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIxOCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyMzEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjE2NSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjQ2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwNCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1OCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI0MSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxOTEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA2In1dfX0seyJuYW1lIjoiY29udHJhY3QiLCJ2YWx1ZSI6eyJ0eXBlIjoiU3RyaW5nIiwidmFsdWUiOiJMVVNEIn19XX19Cg=="
          }
        ]
      }
    ]

    updated_events = [
      %{
        "block_id" => "5baa81b99de13e4b4e22080a88aeec3e7aef51fe80aad9f6a5017c40d224e6c9",
        "block_height" => "15",
        "block_timestamp" => "2022-11-29T04:57:00.842612413Z",
        "events" => [
          %{
            "type" => "flow.AccountContractUpdated",
            "transaction_id" =>
              "441f1f480caf9bd1f693d753402193abae7327b778cf0291882b1c91a802be76",
            "transaction_index" => "1",
            "event_index" => "1",
            "payload" =>
              "eyJ0eXBlIjoiRXZlbnQiLCJ2YWx1ZSI6eyJpZCI6ImZsb3cuQWNjb3VudENvbnRyYWN0QWRkZWQiLCJmaWVsZHMiOlt7Im5hbWUiOiJhZGRyZXNzIiwidmFsdWUiOnsidHlwZSI6IkFkZHJlc3MiLCJ2YWx1ZSI6IjB4MjVlYzhjY2U1NjZjNGNhNyJ9fSx7Im5hbWUiOiJjb2RlSGFzaCIsInZhbHVlIjp7InR5cGUiOiJBcnJheSIsInZhbHVlIjpbeyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExOCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxNzQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIzOSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI4MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTgwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjkwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjkxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIzMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyNTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiODUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjI1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIxOCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyMzEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjE2NSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjQ2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwNCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1OCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI0MSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxOTEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA2In1dfX0seyJuYW1lIjoiY29udHJhY3QiLCJ2YWx1ZSI6eyJ0eXBlIjoiU3RyaW5nIiwidmFsdWUiOiJMVVNEIn19XX19Cg=="
          }
        ]
      }
    ]

    removed_events = [
      %{
        "block_id" => "5baa81b99de13e4b4e22080a88aeec3e7aef51fe80aad9f6a5017c40d224e6c9",
        "block_height" => "25",
        "block_timestamp" => "2022-11-29T05:57:00.842612413Z",
        "events" => [
          %{
            "type" => "flow.AccountContractRemoved",
            "transaction_id" =>
              "441f1f480caf9bd1f693d753402193abae7327b778cf0291882b1c91a802be76",
            "transaction_index" => "2",
            "event_index" => "1",
            "payload" =>
              "eyJ0eXBlIjoiRXZlbnQiLCJ2YWx1ZSI6eyJpZCI6ImZsb3cuQWNjb3VudENvbnRyYWN0QWRkZWQiLCJmaWVsZHMiOlt7Im5hbWUiOiJhZGRyZXNzIiwidmFsdWUiOnsidHlwZSI6IkFkZHJlc3MiLCJ2YWx1ZSI6IjB4MjVlYzhjY2U1NjZjNGNhNyJ9fSx7Im5hbWUiOiJjb2RlSGFzaCIsInZhbHVlIjp7InR5cGUiOiJBcnJheSIsInZhbHVlIjpbeyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjExOCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxNzQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIzOSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI4MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMzIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTgwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjkwIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjkxIn0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIzMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyNTIifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiODUifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjI1In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjIxOCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2MyJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NiJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyMSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI2NCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIyMzEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA3In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjE2NSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxMDQifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMjQ2In0seyJ0eXBlIjoiVUludDgiLCJ2YWx1ZSI6IjEwNCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI1OCJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiI0MSJ9LHsidHlwZSI6IlVJbnQ4IiwidmFsdWUiOiIxOTEifSx7InR5cGUiOiJVSW50OCIsInZhbHVlIjoiMTA2In1dfX0seyJuYW1lIjoiY29udHJhY3QiLCJ2YWx1ZSI6eyJ0eXBlIjoiU3RyaW5nIiwidmFsdWUiOiJMVVNEIn19XX19Cg=="
          }
        ]
      }
    ]

    [added_events: added_events, updated_events: updated_events, removed_events: removed_events]
  end
end
