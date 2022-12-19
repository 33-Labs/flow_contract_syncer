defmodule FlowContractSyncer.DependencyParserTest do
  use FlowContractSyncer.DataCase
  import FlowContractSyncer.ContractEventCase

  alias FlowContractSyncer.Schema.Contract

  alias FlowContractSyncer.{
    DependencyParser
  }

  setup :create_network
  setup :create_contracts

  test "should sync contracts successfully", %{
    network: network,
    contracts: [contract_1, contract_2, contract_3]
  } do
    DependencyParser.start_link(network)
    Process.sleep(500)

    contract_1 = Repo.preload(contract_1, [:dependencies, :dependants])
    assert Enum.count(contract_1.dependencies) == 0
    assert Enum.count(contract_1.dependants) == 2

    contract_2 = Repo.preload(contract_2, [:dependencies, :dependants])
    assert Enum.count(contract_2.dependencies) == 1
    assert Enum.count(contract_2.dependants) == 0

    contract_3 = Repo.preload(contract_3, [:dependencies, :dependants])
    assert Enum.count(contract_3.dependencies) == 1
    assert Enum.count(contract_3.dependants) == 0
  end

  defp create_contracts(context) do
    network = context[:network]

    contract_1 =
      %Contract{
        network_id: network.id,
        uuid: "A.25ec8cce566c4ca7.LUSD",
        address: "0x25ec8cce566c4ca7",
        name: "LUSD",
        status: :normal,
        code: "",
        deps_parsed: false,
        code_parsed: false
      }
      |> Repo.insert!()

    contract_2 =
      %Contract{
        network_id: network.id,
        uuid: "A.25ec8cce566c4ca7.RUSD",
        address: "0x25ec8cce566c4ca7",
        name: "RUSD",
        status: :normal,
        code: "import LUSD from 0x25ec8cce566c4ca7\n/// SINGLE LINE COMMENT",
        deps_parsed: false,
        code_parsed: false
      }
      |> Repo.insert!()

    contract_3 =
      %Contract{
        network_id: network.id,
        uuid: "A.25ec8cce566c4ca7.SUSD",
        address: "0x25ec8cce566c4ca7",
        name: "SUSD",
        status: :normal,
        code: "/** COMMENTS LINE 1 \n COMMENTS LINE 2 **/\nimport LUSD from 0x25ec8cce566c4ca7\n",
        deps_parsed: false,
        code_parsed: false
      }
      |> Repo.insert!()

    [contracts: [contract_1, contract_2, contract_3]]
  end
end
