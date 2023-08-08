defmodule DemoWeb.WebhookController do
  use DemoWeb, :controller
  use Params

  alias Demo.Twilio

  require Logger

  use Params

  defparams(
    message(%{
      profile_id!: :string,
      name_on_card: :string,
      to_phone_number!: :string,
      reviewer_action!: :string
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
    params = params |> transform_params()
    changeset = params |> message()

    if changeset.valid? do
      first_name = get_first_name(params["name_on_card"])
      client_message = get_client_message(params["reviewer_action"], first_name)

      Twilio.send_message(params["to_phone_number"], client_message, params)
    else
      Logger.error("Received invalid request body from RD - #{inspect(params)}")
      Logger.error("Task details are - #{inspect(params["tasks"])}")

      resp = update_response(params)
      Logger.error("Transformed invalid params from RD are - #{inspect(resp)} ")
    end
  end

  def transform_params(params) do
    %{
      "name_on_card" => get_value(params, "philippines_driving_license.nil.name.7.nil"),
      "to_phone_number" => get_value(params, "nil.nil.mobile_numbers.1.nil"),
      "reviewer_action" => params["reviewer_action"],
      "profile_id" => params["profile_id"]
    }
  end

  def get_value(params, ref_id) do
    object =
      params
      |> get_in(["resources", "text"])
      |> Enum.filter(fn text_data -> text_data["ref_id"] == ref_id end)
      |> List.first()

    if is_map(object), do: Map.get(object, "value", ""), else: ""
  end

  def update_response(params) do
    params |> put_in(["resources", "images"], nil) |> put_in(["tasks"], nil)
  end

  def get_first_name(name) when is_binary(name) do
    name |> String.split(" ") |> List.first()
  end

  def get_first_name(_), do: ""

  def get_client_message("approved", first_name) do
    get_success_message(first_name)
  end

  def get_client_message(_, first_name) do
    get_failure_message(first_name)
  end

  def get_success_message(_first_name) do
    "Approve -
    Greetings!
    Nakumpirma na ang iyong mga kinakailangang dokumento, at maaari ka nang dumalo sa proseso ng onboarding upang ma-activate ang app.
    Tiyakin na nasa magandang kondisyon at nasa standard na setup ang iyong motorsiklo.
    Mangyaring dalhin ang isang Android Phone na may hindi bababa sa Bersyon 9.0 (Hindi pinapayagan ang iPhone at Huawei), isang ballpoint pen, at either P1000 (down payment) o P2990 (full payment) para sa iyong Biker Kit na gagamitin.
    Ipakita ang tekstong ito sa venue.
    Kung ikaw ay isang Angkas Biker na, WAG NA ITONG basahin."
  end

  def get_failure_message(_first_name) do
    "Hi!
    Salamat sa iyong pagsali sa Angkas. Hindi namin mai-process ang inyong application, dahil Blurred or Expired or Wala kang pinasang requirements.
    Kung ikaw ay may kumpleto nang requirements ay maaari ka ng magpareserved ng schedule sa link na ito: https://calendly.com/onboarding-cainta
    Dalhin ang kumpletong requirements sa araw na iyong pinili. Kung walang available schedule ay balikan at icheck ang link sa ibang araw.
    Note: Kung ikaw ay Angkas Biker na, please DISREGARD this message"
  end
end
