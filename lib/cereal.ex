defmodule Cereal do

  defstruct [hostname: nil,
             serial: nil,
             version: nil,
             image: nil,
             model: nil]

  def switch() do
    hostname = case hostname() do
                 {:ok, hostname} -> hostname
                 {:error, msg} -> msg
               end

  end

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

        listen(acc)

    after 1_300 -> acc
    end
  end

  def speak(data) do
    start_link |> send_data(data <> "\r\n")
  end

  def hostname() do
    speak "sh run | inc hostname"
    IO.puts "Retrieving switch hostname..."
    result = listen()
    %{"hostname" => hostname} = Regex.named_captures(
      ~r/hostname\s(?<hostname>\w+)/, result)
    cond do
      hostname == nil ->
        {:error, "Unable to retrieve hostname"}
      true ->
        {:ok, hostname}
    end
  end

  def serial() do
    speak "sh inv | inc SN:"
    IO.puts "Retrieving serial number..."
    %{"serial" => serial_1} = Regex.named_captures(
      ~r/SN:\s(?<serial>\w+)/, listen())

    speak "sh ver | inc System serial"
    IO.puts "Retrieving serial number..."
    %{"serial" => serial_2} = Regex.named_captures(
      ~r/\w+:\s(?<serial>\w+)/, listen())

    IO.puts "Checking serial number..."

    cond do
      serial_1 == serial_2 ->
        {:ok, serial_1}
      true ->
        {:error, "Serial number mismatch"}
    end
  end

  def model() do
    speak "sh ver | inc Model number"
    IO.puts "Retrieving model number..."
    %{"model" => model_1} = Regex.named_captures(
      ~r/(?<model>\w+-\w+-\w+)/, listen())

    speak "sh inv | inc PID:"
    IO.puts "Retrieving model number..."
    %{"model" => model_2} = Regex.named_captures(
      ~r/(?<model>\w+-\w+-\w+)/, listen())

    IO.puts "Checking model number..."

    cond do
      model_1 == model_2 ->
        {:ok, model_1}
      true ->
        {:error, "Model number mismatch"}
    end
  end

  def version() do
    speak "sh ver | inc Version"
    IO.puts "Retrieving software version..."
    %{"version" => version} = Regex.named_captures(
      ~r/Version\s(?<version>\d{2}\.[\w\.)?(?]+)/, listen())
    cond do
      version == nil ->
        {:error, "Version not found"}
      true ->
        {:ok, version}
    end
  end

  def image() do
    speak "sh ver | inc image"
    IO.puts "Retrieving software image..."
    %{"image" => image} = Regex.named_captures(
      ~r/"flash:\/(?<image>\w+-\w+-\w+\.\d+-\d+\.\w+)/, listen())
    cond do
      image == nil ->
        {:error, "image"}
      true ->
        {:ok, image}
    end
  end

  def sh_inv() do
    hostname = hostname()
    speak "sh inv"
    IO.puts "Retrieving results from 'show inventory' command..."
    File.write!(hostname <> "-sh_inv.txt", listen())
  end
end
