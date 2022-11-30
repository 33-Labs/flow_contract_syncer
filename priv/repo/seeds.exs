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

alias FlowContractSyncer.Schema.Network

# Insert mainnet

%Network{}
|> Network.changeset(%{
  name: "mainnet", 
  endpoint: "https://rest-mainnet.onflow.org/v1",
  min_sync_height: 1000
})
|> Repo.insert()

# migrate data


