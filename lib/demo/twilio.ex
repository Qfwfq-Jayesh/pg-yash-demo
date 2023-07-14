defmodule Demo.Twilio do
  require Logger

  def send_message(to_phone_number, message, metadata, retry_count) when retry_count > 2 do
    log_error("Exhausted all retries when sending message", metadata)
  end

  def send_message(to_phone_number, message, metadata, retry_count \\ 0) do
    log_info("Retrying message for retry count #{retry_count}", metadata)
    url = System.get_env("TWILIO_MSG_API_URL")
    from_phone_number = System.get_env("TWILIO_FROM_PHONE_NUMBER")

    user = System.get_env("TWILIO_USER")
    password = System.get_env("TWILIO_PASSOWRD")

    payload = %{
      "To" => to_phone_number,
      "From" => from_phone_number,
      "Body" => message
    }

    request_body = URI.encode_query(payload)

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/x-www-form-urlencoded; charset=utf-8"}
    ]

    case HTTPoison.post(url, request_body, headers,
           hackney: [basic_auth: {"#{user}", "#{password}"}]
         ) do
      {:ok, %HTTPoison.Response{status_code: 201, body: body}} ->
        log_info("Received response is #{inspect(body)}", metadata)

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
      when status_code in 400..499 ->
        log_warn(
          "Received a bad request with status code #{status_code} and response body #{inspect(body)}",
          metadata
        )

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        log_warn(
          "Received a request with status code #{status_code} and response body #{inspect(body)}",
          metadata
        )

        :timer.sleep(500) && send_message(to_phone_number, message, metadata, retry_count + 1)

      {:error, %HTTPoison.Error{reason: reason}} ->
        log_error("Failed to send a request with reason #{inspect(reason)}", metadata)
    end
  end

  def log_info(message, metadata) do
    message = Map.merge(metadata, %{"message" => message}) |> Jason.encode!()
    Logger.info(message)
  end

  def log_warn(message, metadata) do
    message = Map.merge(metadata, %{"message" => message}) |> Jason.encode!()
    Logger.warn(message)
  end

  def log_error(message, metadata) do
    message = Map.merge(metadata, %{"message" => message}) |> Jason.encode!()
    Logger.error(message)
  end
end
