defmodule FlowContractSyncer.GlobalSetup do
  @moduledoc false

  alias FlowContractSyncer.Repo
  alias FlowContractSyncer.Schema.{Contract, ContractEvent, Network}

  NimbleCSV.define(ContractParser, separator: ",", escape: "\"")
  NimbleCSV.define(EventParser, separator: ",", escape: "\#")

  @start_height 41_780_000

  def setup_network do
    %Network{}
    |> Network.changeset(%{
      name: "mainnet",
      endpoint: "https://rest-mainnet.onflow.org/v1",
      min_sync_height: @start_height,
      is_enabled: true,
      config: %{
        "contract_event_sync_interval" => 100,
        "contract_event_sync_chunk_size" => 249,
        "contract_sync_interval" => 1000,
        "contract_sync_chunk_size" => 20,
        "deps_parse_interval" => 1000,
        "deps_parse_chunk_size" => 250
      }
    })
    |> Repo.insert()
  end

  def insert_contracts do
    mainnet = Repo.get_by(Network, name: "mainnet")

    changesets =
      "priv/data/contracts.csv"
      |> File.stream!(read_ahead: 100_000)
      |> ContractParser.parse_stream()
      |> Stream.map(fn [location, code] ->
        ["A", raw_address, name] = String.split(location, ".")

        %Contract{}
        |> Contract.changeset(%{
          network_id: mainnet.id,
          uuid: location,
          address: "0x" <> raw_address,
          name: name,
          status: :normal,
          code: code,
          deps_parsed: false,
          snippet_parsed: false
        })
      end)

    Repo.transaction(
      fn ->
        Enum.each(changesets, fn changeset ->
          changeset
          |> Repo.insert!()
        end)
      end,
      timeout: :infinity
    )
  end

  def insert_events do
    mainnet = Repo.get_by(Network, name: "mainnet")

    changesets =
      "priv/data/events.csv"
      |> File.stream!(read_ahead: 1)
      |> EventParser.parse_stream()
      |> Stream.filter(fn [_, _, block_height | _data] ->
        String.to_integer(block_height) < @start_height
      end)
      |> Stream.map(fn
        [
          tx_id,
          block_timestamp,
          block_height,
          "true",
          event_index,
          _event_contract,
          event_type | event_data
        ] = line ->
          block_height = String.to_integer(block_height)

          type =
            case event_type do
              "AccountContractAdded" -> :added
              "AccountContractUpdated" -> :updated
              "AccountContractRemoved" -> :removed
            end

          digest =
            line
            |> Jason.encode!()
            |> (fn data -> :crypto.hash(:sha256, data) end).()
            |> Base.encode16()

          payload = event_data |> Enum.join(",") |> Jason.decode!()
          address = payload["address"]
          contract = payload["contract"]

          code_hash =
            payload["codeHash"]
            |> Jason.decode!()
            |> Enum.map(fn
              %{"type" => "UInt8", "value" => value} -> String.to_integer(value)
              value when is_integer(value) -> value
            end)
            |> List.to_string()
            |> Base.encode16()

          %ContractEvent{}
          |> ContractEvent.changeset(%{
            network_id: mainnet.id,
            digest: digest,
            block_height: block_height,
            block_timestamp: NaiveDateTime.from_iso8601!(block_timestamp),
            tx_id: tx_id,
            # no tx index data in flipcrypto
            tx_index: 0,
            type: type,
            index: String.to_integer(event_index),
            address: address,
            code_hash: code_hash,
            contract_name: contract,
            processed: true
          })
      end)

    Repo.transaction(
      fn ->
        Enum.each(changesets, fn changeset ->
          changeset
          |> Repo.insert!()
        end)
      end,
      timeout: :infinity
    )
  end
end
