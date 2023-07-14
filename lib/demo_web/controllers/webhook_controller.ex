defmodule DemoWeb.WebhookController do
  use DemoWeb, :controller
  use Params

  alias Demo.Twilio

  require Logger

  use Params

  defparams(
    message(%{
      profile_id!: :string,
      name_on_card!: :string,
      to_phone_number!: :string,
      is_approved!: :boolean
    })
  )

  def handle_webhook(conn, params) do
    Logger.info("Webhook received!")
    Task.start(fn -> process_request(params) end)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, %{"status" => "success"} |> Jason.encode!())
  end

  def process_request(params) do
    changeset = message(params)

    client_message = get_client_message(params["is_approved"])

    if changeset.valid? do
      metadata = %{
        "profile_id" => params["profile_id"],
        "name_on_card" => params["name_on_card"],
        "to_phone_number" => params["to_phone_number"],
        "is_approved" => params["is_approved"]
      }

      Twilio.send_message(params["to_phone_number"], client_message, metadata)
    else
      Logger.error("Received invalid request body from RD - #{inspect(params)}")
    end
  end

  def get_client_message(true) do
    get_success_message()
  end

  def get_client_message(status) when is_binary(status) do
    get_client_message(String.downcase(status))
  end

  def get_client_message("true") do
    get_success_message()
  end

  def get_client_message(_) do
    get_failure_message()
  end

  def get_success_message() do
    "Profile is approved!"
  end

  def get_failure_message() do
    "Profile is not approved!"
  end
end
