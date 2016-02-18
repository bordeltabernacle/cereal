defmodule CerealStruct do

  defstruct [hostname: nil,
             serial: nil,
             version: nil,
             image: nil,
             model: nil]

end

defmodule Cereal do

  @hostname_regex ~r/hostname\s(?<hostname>\w+)/
  @model_regex ~r/(?<model>\w+-\w+-\w+)/
  @sh_ver_serial_regex ~r/\w+:\s(?<serial>\w+)/
  @sh_inv_serial_regex ~r/SN:\s(?<serial>\w+)/
  @image_regex ~r/"flash:\/(?<image>\w+-\w+-\w+\.\d+-\d+\.\w+)/
  @version_regex ~r/Version\s(?<version>\d{2}\.[\w\.)?(?]+)/

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

    after 2_000 -> acc
    end
  end

  def speak(data) do
    start_link |> send_data(data <> "\r\n")
  end

  def switch_map() do
    switch = %CerealStruct{hostname: hostname(),
            serial: serial(),
            version: version(),
            image: image(),
            model: model()}
    IO.puts "\nHostname:\t\t\t\t#{switch.hostname}\nSerial Number:\t#{switch.serial}\nVersion:\t\t\t\t#{switch.version}\nImage:\t\t\t\t\t#{switch.image}\nModel:\t\t\t\t\t#{switch.model}\n"
  end

  def hostname() do
    speak "sh run | inc hostname"
    IO.puts "Retrieving switch hostname..."
    result = listen()
    %{"hostname" => hostname} = Regex.named_captures(
      @hostname_regex, result)
    hostname
  end

  def serial() do
    speak "sh inv | inc SN:"
    IO.puts "Retrieving serial number..."
    %{"serial" => serial_1} = Regex.named_captures(
      @sh_inv_serial_regex, listen())

    speak "sh ver | inc System serial"
    IO.puts "Retrieving serial number..."
    %{"serial" => serial_2} = Regex.named_captures(
      @sh_ver_serial_regex, listen())

    IO.puts "Checking serial number..."

    cond do
      serial_1 == serial_2 ->
        serial_1
      true ->
        :mismatch
    end
  end

  def model() do
    speak "sh ver | inc Model number"
    IO.puts "Retrieving model number..."
    %{"model" => model_1} = Regex.named_captures(
      @model_regex, listen())

    speak "sh inv | inc PID:"
    IO.puts "Retrieving model number..."
    %{"model" => model_2} = Regex.named_captures(
      @model_regex, listen())

    IO.puts "Checking model number..."

    cond do
      model_1 == model_2 ->
        model_1
      true ->
        :mismatch
    end
  end

  def version() do
    speak "sh ver | inc Version"
    IO.puts "Retrieving software version..."
    %{"version" => version} = Regex.named_captures(
      @version_regex, listen())
    version
  end

  def image() do
    speak "sh ver | inc image"
    IO.puts "Retrieving software image..."
    %{"image" => image} = Regex.named_captures(
      @image_regex, listen())
    image
  end

  def sh_inv() do
    hostname = hostname()
    speak "sh inv"
    IO.puts "Retrieving results from 'show inventory' command..."
    File.write!(hostname <> "-sh_inv.txt", listen())
  end
end
