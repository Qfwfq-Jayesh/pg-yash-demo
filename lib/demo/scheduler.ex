defmodule Demo.Scheduler do
  use Quantum, otp_app: :demo

  require Logger

  def cron() do
    Task.start(fn -> HTTPoison.get("https://pg-yash-demo.onrender.com/") end)
  end
end
