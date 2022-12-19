defmodule FlowContractSyncer.SnippetTest do
  use FlowContractSyncer.DataCase

  alias FlowContractSyncer.Schema.Snippet

  setup :setup_code

  test "should parse structs correctly", %{code: code} do
    snippets = Snippet.get_structs(code)
    assert Enum.count(snippets) == 2
    want = [
      """
      pub struct EmptyStruct {}
      """,
      """
      pub struct StructWithFieldsAndFuncs : 
          StructInterface1, 
          StructInterface2 
      {
          pub let field1: String
          pub let field2: {String: AnyStruct}

          init(field1: String, field2: {String: AnyStruct}) {
              self.field1 = field1
              self.field2 = field2
          }

          pub fun getStatus(): String {
              return ""
          }
      }
      """
    ]
    want = want |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    get = snippets |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    assert get == want
  end

  test "should parse struct interfaces correctly", %{code: code} do
    snippets = Snippet.get_struct_interfaces(code)
    assert Enum.count(snippets) == 2
    want = [
      """
      pub struct interface StructInterface1 {
        pub let field1: String
      }
      """,
      """
      pub struct interface StructInterface2 {
        pub let field2: {String: AnyStruct}
      }
      """
    ]
    want = want |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    get = snippets |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    assert get == want
  end

  test "should parse resources correctly", %{code: code} do
    snippets = Snippet.get_resources(code)
    assert Enum.count(snippets) == 2
    want = [
      """
      pub resource EmptyResource {}
      """,
      """
      pub resource ResourceWithFieldsAndFuncs : 
          ResourceInterface1,                     ResourceInterface2, AfunTest, AreturnTest {
          pub let field1: String
          pub let field2: {String: AnyStruct}

          init(field1: String, field2: {String: AnyStruct}) {
              self.field1 = field1
              self.field2 = field2
          }

          pub fun getStatus(): String {
              return "Hello"
          }

          destroy() {
          }
      }
      """
    ]
    want = want |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    get = snippets |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    assert get == want
  end

  test "should parse resource interfaces correctly", %{code: code} do
    snippets = Snippet.get_resource_interfaces(code)
    assert Enum.count(snippets) == 4
    want = [
      """
      pub resource interface ResourceInterface1 {
        pub let field1: String
      }
      """,
      """
      pub resource interface ResourceInterface2 {
        pub let field2: {String: AnyStruct}
      }
      """,
      """
      pub resource interface AfunTest {
      }
      """,
      """
      pub resource interface AreturnTest {
      }
      """
    ]
    want = want |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    get = snippets |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    assert get == want
  end

  test "should parse functions with return correctly", %{code: code} do
    snippets = Snippet.get_functions_with_return(code)
    assert Enum.count(snippets) == 6
    want = [
      ~S"""
        pub fun getStatus(): String {
          return ""
      }
      """,
      """
        pub fun getStatus(): String {
          return "Hello"
      }
      """,
      """
        pub fun createEmptyResource(): @EmptyResource {
          return <- create EmptyResource()
      }
      """,
      """
            pub fun createEmptyResourceWithParams (field1: String)   : 
            @EmptyResource 
      {
      return <- create EmptyResource()
      }
      """,
      """
            pub fun funtionWithRestrictionsAsReturnValue()     : @AnyResource{ResourceInterface1, AfunTest, AreturnTest} {
              let a = fun (b: Int): Int {
              return b + 1
          }
      return<- create ResourceWithFieldsAndFuncs(field1: "TEST", field2: {})   
      }
      """,
      """
            pub fun funtionWithRestrictionsAsReturnValue2()     : @AnyResource{ResourceInterface1, AfunTest, AreturnTest} {
              let a = fun (b: Int): Int {
              return b + 1
          }
      return<- create ResourceWithFieldsAndFuncs(field1: "TEST", field2: {})   
      }
      """
    ]

    want = want |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    get = snippets |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    assert get == want
  end

  test "should parse functions without return correctly", %{code: code} do
    snippets = Snippet.get_functions_without_return(code)
    assert Enum.count(snippets) == 1
    want =
    """
          pub fun functionWithNoReturnValue() {
              let a =fun (b: Int): Int {
                  return b + 1
              }
  
                          let c =fun(b: Int): Int {
                  return b + 1
              }
  
      let d = fun             (b: Int)      : Int {
                  return b + 1
              }
      }
    """
    |> String.trim()

    [snippet | _ ] = snippets
    assert String.trim(snippet) == want
  end

  test "should parse enums correctly", %{code: code} do
    snippets = Snippet.get_enums(code)
    assert Enum.count(snippets) == 2
    want = [
      """
      pub enum TestEnum: UInt8 {
        pub case number1
        pub case number2
      }
      """,
      """
      pub enum TestEnum2 : UInt8 {
        pub case number1
        pub case number2
      }
      """
    ]

    want = want |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    get = snippets |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    assert get == want
  end

  test "should parse events correctly", %{code: code} do
    snippets = Snippet.get_events(code)
    assert Enum.count(snippets) == 3
    want = [
      """
      pub event Event()
      """,
      """
      pub event EventWithParams(param1: UInt64, param2: String)
      """,
      """
      pub event EventWithParams2   (
        param1: UInt64, 
        param2: String
      )
      """
    ]
    want = want |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    get = snippets |> Enum.map(& String.replace(&1, [" ", "\n"], ""))
    assert get == want
  end

  def setup_code(__context) do
    code = 
    """
    pub contract RegexTester {
      // event
      pub event Event()
  
      // event with params
      pub event EventWithParams(param1: UInt64, param2: String)
      pub event EventWithParams2   (
          param1: UInt64,
          param2: String
      )
  
      // enum
      pub enum TestEnum: UInt8 {
          pub case number1
          pub case number2
      }
  
      pub enum TestEnum2 : UInt8 {
          pub case number1
          pub case number2
      }
  
      // struct interfaces
      pub struct interface StructInterface1 {
          pub let field1: String
      }
  
      pub struct interface StructInterface2 {
          pub let field2: {String: AnyStruct}
      }
  
      // resource interfaces
      pub resource interface ResourceInterface1 {
          pub let field1: String
      }
  
      pub resource interface ResourceInterface2 {
          pub let field2: {String: AnyStruct}
      }
  
      // empty struct
      pub struct EmptyStruct {}
      
      // full struct not formatted
      pub struct StructWithFieldsAndFuncs :
          StructInterface1,
          StructInterface2
      {
          pub let field1: String
          pub let field2: {String: AnyStruct}
  
          init(field1: String, field2: {String: AnyStruct}) {
              self.field1 = field1
              self.field2 = field2
          }
  
          pub fun getStatus(): String {
              return ""
          }
      }
  
      // empty resource
      pub resource EmptyResource {}
  
      // full resource not formatted
      pub resource ResourceWithFieldsAndFuncs :
          ResourceInterface1,                     ResourceInterface2, AfunTest, AreturnTest {
          pub let field1: String
          pub let field2: {String: AnyStruct}
  
          init(field1: String, field2: {String: AnyStruct}) {
              self.field1 = field1
              self.field2 = field2
          }
  
          pub fun getStatus(): String {
              return "Hello"
          }
  
          destroy() {
          }
      }
  
      // functions
  
      // function with nested function
      pub fun functionWithNoReturnValue() {
              let a =fun (b: Int): Int {
                  return b + 1
              }
  
                          let c =fun(b: Int): Int {
                  return b + 1
              }
  
      let d = fun             (b: Int)      : Int {
                  return b + 1
              }
      }
  
      pub fun createEmptyResource(): @EmptyResource {
          return <- create EmptyResource()
      }
  
      // function with params and unformatted
      pub fun createEmptyResourceWithParams (field1: String)   :
               @EmptyResource
      {
          return <- create EmptyResource()
      }
  
      pub resource interface AfunTest {
      }
  
      pub resource interface AreturnTest {
      }
  
      pub fun funtionWithRestrictionsAsReturnValue()     : @AnyResource{ResourceInterface1, AfunTest, AreturnTest} {
                  let a = fun (b: Int): Int {
                  return b + 1
              }
        return<- create ResourceWithFieldsAndFuncs(field1: "TEST", field2: {})
      }
  
          pub fun funtionWithRestrictionsAsReturnValue2()     : @AnyResource{ResourceInterface1, AfunTest, AreturnTest} {
                  let a = fun (b: Int): Int {
                  return b + 1
              }
        return<- create ResourceWithFieldsAndFuncs(field1: "TEST", field2: {})
      }
  
      init() {
      }
    }
    """

    [code: code]
  end
end