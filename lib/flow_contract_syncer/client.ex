defmodule FlowContractSyncer.Client do
  @moduledoc """
  Client for interacting with Flow blockchain 
  """

  def get_latest_block_height(opts) do
    case get_latest_block_header(opts) do
      {:ok, [%{"header" => %{"height" => height}}]} -> String.to_integer(height)   
      _otherwise -> nil
    end
  end

  def get_latest_block_header(opts) do
    network = opts[:network] || :testnet
    endpoint = network |> access_api() |> Path.join("blocks")

    query = %{ "height" => "sealed" }
    encoded_query = URI.encode_query(query, :rfc3986)

    url = "#{endpoint}?#{encoded_query}"

    Finch.build(:get, url, [{"Content-Type", "application/json"}])
    |> Finch.request(MyFinch)
    |> handle_response() 
  end

  # e.g. FlowContractSyncer.Client.get_events("flow.AccountContractAdded", 86934521, 86934721, network: :testnet)
  def get_events(type, start_height, end_height, opts) do
    network = opts[:network] || :testnet
    endpoint = network |> access_api() |> Path.join("events")

    query = %{
      "type" => type,
      "start_height" => start_height,
      "end_height" => end_height
    }
    encoded_query = URI.encode_query(query, :rfc3986)

    url = "#{endpoint}?#{encoded_query}"

    Finch.build(:get, url, [{"Content-Type", "application/json"}])
    |> Finch.request(MyFinch)
    |> handle_response()
  end

  # NOTE: the block_height must be a recent block, or an error will be returned
  # {
  #   "code": 400,
  #   "message": "Invalid Flow argument: failed to execute the script on the execution node execution-5f6c73a22445d7d958c6a37c1f3be99c72cacd39894a3e46d6647a9adb007b4d@execution-001.devnet38.nodes.onflow.org:3569=100: rpc error: code = InvalidArgument desc = failed to execute script: failed to execute script at block (708cdae06523fdebd99f773d5fb8b6ff66804339c3d5a9671d6df595211c44fd): state commitment not found (00c6d6995b0f1eb301ad15e54691b3fcaf0673b40a91324d84d28e1a29e7d7d9). this error usually happens if the reference block for this script is not set to a recent block"
  # }
  # So we cannot get the old versions of a contract
  # e.g. FlowContractSyncer.ContractSyncer.get_contract("0x25ec8cce566c4ca7", "LUSD", block_height: 86942759)
  def execute_script(encoded_script, encoded_arguments, opts) do
    network = opts[:network] || :testnet
    endpoint = network |> access_api() |> Path.join("scripts")

    url =
      case opts[:block_height] do
        height when is_integer(height) or is_binary(height) ->
          query = %{ "block_height" => height }
          encoded_query = URI.encode_query(query, :rfc3986)
          "#{endpoint}?#{encoded_query}"

        _otherwise -> endpoint
      end

    body = %{
      "script" => encoded_script,
      "arguments" => encoded_arguments
    } |> Jason.encode!()

    Finch.build(:post, url, [{"Content-Type", "application/json"}], body)
    |> Finch.request(MyFinch)
    |> handle_response()
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, content} -> {:ok, content}
      error -> {:resp_error, :decode_error}
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"code" => code, "message" => message}} ->
        {:error, status, "#{code}_#{message}"}
      error -> {:resp_error, :decode_error}
    end
  end

  defp handle_response(error) do
    {:resp_error, error}
  end

  defp access_api(network) when network in [:mainnet, :testnet] do
    endpoints = Application.get_env(:flow_contract_syncer, :access_api)
    endpoints[network]
  end
end