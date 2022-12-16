# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FlowContractSyncer.Repo.insert!(%FlowContractSyncer.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias FlowContractSyncer.Repo

alias FlowContractSyncer.Schema.{Contract, Network}

# Insert mainnet

%Network{}
|> Network.changeset(%{
  name: "mainnet",
  endpoint: "https://rest-mainnet.onflow.org/v1",
  min_sync_height: 41780000,
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

mainnet = Repo.get_by(Network, name: "mainnet")

# migrate data

NimbleCSV.define(MyParser, separator: ",", escape: "\"")

changesets =
  "priv/data/contracts.csv"
  |> File.stream!(read_ahead: 100_000)
  |> MyParser.parse_stream()
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
      parsed: false
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
