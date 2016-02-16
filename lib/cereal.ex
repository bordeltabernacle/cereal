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
  end

  def receive_serial_data(acc \\ "") do
    receive do
      {:elixir_serial, _serial_pid, data} when is_binary(data) ->
        acc = acc <> data

        if String.ends_with?(acc, "\r\n") do
          IO.puts String.strip(acc)
          acc = ""
        end

        receive_serial_data(acc)

    after 1_000 -> IO.puts "no dice"
    end
  end
end
