defmodule Demo.Scheduler do
  use Quantum, otp_app: :demo

  require Logger

  def cron() do
    Logger.info("Server runinng ...")
  end
end
