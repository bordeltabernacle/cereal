defmodule Cereal do

  def start_link(port \\ "/dev/ttyUSB0", baud \\ 9600) do
    {:ok, serial} = Serial.start_link
    Serial.open(serial, port)
    Serial.set_speed(serial, baud)
    Serial.connect(serial)
    serial
  end

  def send_data(serial_pid, data) do
    Serial.send_data(serial_pid, data)
  end

  def listen(acc \\ "") do
    receive do
      {:elixir_serial, _serial_pid, data} ->
        acc = acc <> data

        if String.ends_with?(acc, "\r\n") do
          IO.puts String.strip(acc)
          acc = ""
        end

        listen(acc)

    after 500 -> exit(:silence)
    end
  end

  def speak(data) do
    start_link |> send_data(data <> "\r\n")
  end
end
