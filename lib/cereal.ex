defmodule Cereal do

  def start_link(port \\ "/dev/ttyUSB0", baud \\ 9600) do
    {:ok, serial} = Serial.start_link
    Serial.open(serial, port)
    Serial.set_speed(serial, baud)
    Serial.connect(serial)
    {:ok, serial}
  end

  def send_data(serial_pid, data) do
    Serial.send_data(serial_pid, data)
    receive_data
  end

  def receive_data(acc \\ "") do
    receive do
      {:elixir_serial, _serial_pid, data} ->
        acc = acc <> data

        if String.ends_with?(acc, "\r\n") do
          IO.puts(acc)
          acc = ""
        end

        receive_data(acc)

    after
      1_000 -> IO.puts("nothing after 1s")
    end
  end
end
