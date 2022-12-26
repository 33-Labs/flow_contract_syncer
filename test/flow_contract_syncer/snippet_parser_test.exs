defmodule FlowContractSyncer.SnippetParserTest do
  use FlowContractSyncer.DataCase
  import FlowContractSyncer.ContractEventCase

  alias FlowContractSyncer.Schema.{Contract, ContractSnippet, Snippet}

  alias FlowContractSyncer.{
    SnippetParser
  }

  setup :create_network
  setup :create_contract_1
  setup :create_contract_2

  test "should parse contract code successfully", %{
    network: network,
    contract_1: contract_1,
    contract_2: contract_2
  } do
    SnippetParser.start_link(network)
    Process.sleep(500)

    snippets = Repo.all(Snippet)
    assert Enum.count(snippets) == 7
    assert Enum.all?(snippets, &(&1.status == :normal))

    contract_snippets = Repo.all(ContractSnippet)
    assert Enum.count(contract_snippets) == 8

    cs_1 = contract_snippets |> Enum.filter(&(&1.contract_id == contract_1.id))
    assert Enum.count(cs_1) == 7

    cs_2 = contract_snippets |> Enum.filter(&(&1.contract_id == contract_2.id))
    assert Enum.count(cs_2) == 1

    types =
      [:resource, :struct, :resource_interface, :struct_interface, :enum, :event, :function]
      |> Enum.sort()

    types_got = snippets |> Enum.map(& &1.type) |> Enum.sort()
    assert types == types_got
  end

  defp create_contract_1(context) do
    network = context[:network]

    code = """
    pub contract RegexTester {
      // event
      pub event Event()

      // enum
      pub enum TestEnum: UInt8 {
          pub case number1
          pub case number2
      }

      // struct interfaces
      pub struct interface StructInterface1 {
          pub let field1: String
      }

      // resource interfaces
      pub resource interface ResourceInterface1 {
          pub let field1: String
      }

      // empty struct
      pub struct EmptyStruct {}

      // empty resource
      pub resource EmptyResource {}

      // functions
      pub fun createEmptyResource(): @EmptyResource {
          return <- create EmptyResource()
      }

      init() {
      }
    }
    """

    contract =
      %Contract{}
      |> Contract.changeset(%{
        network_id: network.id,
        uuid: "A.25ec8cce566c4ca7.LUSD",
        address: "0x25ec8cce566c4ca7",
        name: "LUSD",
        status: :normal,
        code: code,
        deps_parsed: false,
        snippet_parsed: false
      })
      |> Repo.insert!()

    [contract_1: contract]
  end

  defp create_contract_2(context) do
    network = context[:network]

    code = """
    pub contract RegexTester {
      // functions
      pub fun createEmptyResource(): @EmptyResource {
          return <- create EmptyResource()
      }

      init() {
      }
    }
    """

    contract =
      %Contract{}
      |> Contract.changeset(%{
        network_id: network.id,
        uuid: "A.25ec8cce566c4ca7.LUSD2",
        address: "0x25ec8cce566c4ca7",
        name: "LUSD2",
        status: :normal,
        code: code,
        deps_parsed: false,
        snippet_parsed: false
      })
      |> Repo.insert!()

    [contract_2: contract]
  end
end
