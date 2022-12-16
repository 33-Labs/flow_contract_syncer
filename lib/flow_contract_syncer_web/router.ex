defmodule FlowContractSyncerWeb.Router do
  use FlowContractSyncerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {FlowContractSyncerWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug FlowContractSyncerWeb.Plugs.ApiAuth
  end

  scope "/", FlowContractSyncerWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api/v1", FlowContractSyncerWeb do
    pipe_through [:api, :authenticate_api_user]

    get("/status", StatusController, :show)

    get("/search", ContractSearchController, :search)
    get("/contracts", ContractController, :index)
    get("/contracts/:uuid", ContractController, :show)
    get("/contracts/latest", ContractController, :latest)
    get("/contracts/popular", ContractController, :popular)
    get("/contracts/dependent", ContractController, :popular)
    get("/contracts/sync", ContractController, :sync)
  end

  scope "/api/v1/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :flow_contract_syncer,
      swagger_file: "swagger.json"
  end

  def swagger_info do
    %{
      schemes: ["https", "http"],
      info: %{
        version: "1.0.0",
        title: "FlowContractSyncer API",
        description: "API Documentation for FlowContractSyncer",
        termsOfService: "Open for public",
        contact: %{
          name: "lanford33",
          email: "lanford33@outlook.com"
        }
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          description: "API Token must be provided via `Authorization: Bearer ` header",
          in: "header"
        }
      },
      consumes: ["application/json"],
      produces: ["application/json"],
      tags: [
        %{name: "Contracts", description: "Contract resources"},
        %{name: "Search", description: "Search resources"},
        %{name: "Status", description: "System status"}
      ]
    }
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FlowContractSyncerWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
