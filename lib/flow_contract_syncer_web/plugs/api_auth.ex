defmodule FlowContractSyncerWeb.Plugs.ApiAuth do
  @moduledoc false

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> get_token()
    |> verify_token()
    |> case do
      {:ok, user_name} -> assign(conn, :current_user, user_name)
      _unauthorized -> assign(conn, :current_user, nil)
    end
  end

  def authenticate_api_user(conn, _opts) do
    if Map.get(conn.assigns, :current_user) do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(FlowContractSyncerWeb.ErrorView)
      |> render(:"401")
      |> halt()
    end
  end

  def generate_token(user_name) do
    Phoenix.Token.sign(
      FlowContractSyncerWeb.Endpoint,
      inspect(__MODULE__),
      user_name
    )
  end

  @spec verify_token(nil | binary) :: {:error, :expired | :invalid | :missing} | {:ok, any}
  def verify_token(token) do
    one_year = 30 * 24 * 60 * 60 * 12

    Phoenix.Token.verify(
      FlowContractSyncerWeb.Endpoint,
      inspect(__MODULE__),
      token,
      max_age: one_year
    )
  end

  @spec get_token(Plug.Conn.t()) :: nil | binary
  def get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end
end
