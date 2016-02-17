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

  def listen(pid, acc \\ "") do
    receive do
      {:elixir_serial, _serial_pid, data} when is_binary(data) ->
        acc = acc <> data

        if String.ends_with?(acc, "\r\n") do
          send(pid, {:data, String.strip(acc)})
          #IO.puts String.strip(acc)
          acc = ""
        end

        listen(acc)

    after 1_000 -> IO.puts "no dice"
    end
  end

  def read() do
    receive do
      {:data, data} -> data
    after 2_000 -> exit(:timeout)
    end
  end

  def speak(pid, data) do
    start_link |> send_data(data <> "\r\n")
    listen(pid)
  end
end
