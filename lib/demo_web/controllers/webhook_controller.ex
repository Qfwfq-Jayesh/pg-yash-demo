defmodule DemoWeb.WebhookController do
  use DemoWeb, :controller

  require Logger

  def handle_webhook(conn, _params) do
    Logger.info("Webhook received!")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, %{"status" => "success"} |> Jason.encode!())
  end
end
