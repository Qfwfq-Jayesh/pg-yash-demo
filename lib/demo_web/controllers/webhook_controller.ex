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

    if changeset.valid? do
      metadata = %{
        "profile_id" => params["profile_id"],
        "name_on_card" => params["name_on_card"],
        "to_phone_number" => params["to_phone_number"],
        "is_approved" => params["is_approved"]
      }

      first_name = get_first_name(params["name_on_card"])
      client_message = get_client_message(params["is_approved"], first_name)

      Twilio.send_message(params["to_phone_number"], client_message, metadata)
    else
      Logger.error("Received invalid request body from RD - #{inspect(params)}")

      resp = update_response(params)
      Logger.error("Transformed invalid params from RD are - #{inspect(resp)} ")
    end
  end

  def update_response(params) do
    params |> put_in(["resources", "images"], nil) |> put_in(["tasks"], nil)
  end

  def get_first_name(name) when is_binary(name) do
    name |> String.split(" ") |> List.first()
  end

  def get_first_name(_), do: ""

  def get_client_message(true, first_name) do
    get_success_message(first_name)
  end

  def get_client_message(status, first_name) when is_binary(status) do
    get_client_message(String.downcase(status), first_name)
  end

  def get_client_message("true", first_name) do
    get_success_message(first_name)
  end

  def get_client_message(_, first_name) do
    get_failure_message(first_name)
  end

  def get_success_message(first_name) do
    "Hi #{first_name}! Congratulations!
VERIFIED na iyong requirements, maaari ka nang umattend ng onboarding process para maactivate na ang app. Pumili ng araw nang pagpunta sa link na ito: https://calendly.com/onboarding-cainta
Siguraduhing good condition ang inyong motor at nasa standard setup.

Dalhin din ang ORIGINAL at VALID (HINDI EXPIRED) na requirements, Android Phone na atleast Version 9.0 (Bawal ang Iphone at Huawei), Ballpen at P1000 (down payment) / P2990 (full payment) para sa iyong Biker Kit na gagamitin. IPAKITA ang text na ito sa venue. Kung ikaw ay Angkas Biker na, DISREGARD this message"
  end

  def get_failure_message(first_name) do
    "Hi #{first_name}!
Salamat sa iyong pagsali sa Angkas. Hindi namin mai-process ang inyong application, dahil Blurred or Expired or Wala kang pinasang requirements.
Kung ikaw ay may kumpleto nang requirements ay maaari ka ng magpareserved ng schedule sa link na ito: https://calendly.com/onboarding-cainta
Dalhin ang kumpletong requirements sa araw na iyong pinili. Kung walang available schedule ay balikan at icheck ang link sa ibang araw.
Note: Kung ikaw ay Angkas Biker na, please DISREGARD this message"
  end
end
