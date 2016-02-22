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

  def fetch_switch_data() do
    switch = %Cereal.Switch{
      hostname: fetch_hostname(),
      serial: fetch_serial(),
      version: fetch_sw_version(),
      image: fetch_sw_image(),
      model: fetch_model()}

    sh_inv = fetch_show_command("sh inv")
    sh_ver = fetch_show_command("sh ver")
    sh_run = fetch_show_command("sh run")

    switch
    |> check_switch_data
    |> add_show_command(:inv, sh_inv)
    |> add_show_command(:ver, sh_ver)
    |> add_show_command(:run, sh_run)
    |> write_to_file!
  end

  defp check_switch_data(%Cereal.Switch{hostname: nil} = data) do
    IO.puts "Hostname failed, retrieving hostname..."
    hostname = fetch_hostname()
    %{data | hostname: hostname} |> check_switch_data
  end
  defp check_switch_data(%Cereal.Switch{serial: nil} = data) do
    IO.puts "Serial Number failed, retrieving serial number..."
    serial = fetch_serial()
    %{data | serial: serial} |> check_switch_data
  end
  defp check_switch_data(%Cereal.Switch{serial: :mismatch} = data) do
    IO.puts "Serial Number mismatch, retrieving serial number..."
    serial = fetch_serial()
    %{data | serial: serial} |> check_switch_data
  end
  defp check_switch_data(%Cereal.Switch{version: nil} = data) do
    IO.puts "Version failed, retrieving version..."
    version = fetch_sw_version()
    %{data | version: version} |> check_switch_data
  end
  defp check_switch_data(%Cereal.Switch{image: nil} = data) do
    IO.puts "Software Image failed, retrieving image..."
    image = fetch_sw_image()
    %{data | image: image} |> check_switch_data
  end
  defp check_switch_data(%Cereal.Switch{model: nil} = data) do
    IO.puts "Model failed, retrieving model..."
    model = fetch_model()
    %{data | model: model} |> check_switch_data
  end
  defp check_switch_data(%Cereal.Switch{model: :mismatch} = data) do
    IO.puts "Model mismatch, retrieving model..."
    model = fetch_model()
    %{data | model: model} |> check_switch_data
  end
  defp check_switch_data(data), do: data

  def fetch_hostname() do
    speak "sh run | inc hostname"
    IO.puts "Retrieving switch hostname..."
    result = listen()
    %{"hostname" => hostname} = Regex.named_captures(
      @hostname_regex, result)
    hostname
  end

  def fetch_serial() do
    speak "sh inv | inc SN:"
    IO.puts "Retrieving serial number..."
    %{"serial" => serial_1} = Regex.named_captures(
      @sh_inv_serial_regex, listen())

    speak "sh ver | inc System serial"
    IO.puts "Checking serial number..."
    %{"serial" => serial_2} = Regex.named_captures(
      @sh_ver_serial_regex, listen())

    compare_values(serial_1, serial_2)
  end

  def fetch_model() do
    speak "sh ver | inc Model number"
    IO.puts "Retrieving model number..."
    %{"model" => model_1} = Regex.named_captures(
      @model_regex, listen())

    speak "sh inv | inc PID:"
    IO.puts "Checking model number..."
    %{"model" => model_2} = Regex.named_captures(
      @model_regex, listen())

    compare_values(model_1, model_2)
  end

  defp compare_values(val, val), do: val
  defp compare_values(val_1, val_2) when val_1 != val_2, do: :mismatch

  def fetch_sw_version() do
    speak "sh ver | inc Version"
    IO.puts "Retrieving software version..."
    %{"version" => version} = Regex.named_captures(
      @version_regex, listen())
    version
  end

  def fetch_sw_image() do
    speak "sh ver | inc image"
    IO.puts "Retrieving software image..."
    %{"image" => image} = Regex.named_captures(
      @image_regex, listen())
    image
  end

  def fetch_show_command(command) do
    speak command
    IO.puts "Retrieving results from #{command} command..."
    listen()
  end

  def add_show_command(data, :inv, value), do: %{data | sh_inv: value}
  def add_show_command(data, :ver, value), do: %{data | sh_ver: value}
  def add_show_command(data, :run, value), do: %{data | sh_run: value}

  def write_to_file!(data) do
    IO.puts "Writing to file..."
    content = ~s"""
    =====================================================
    Hostname:\t\t\t\t\t\t#{data.hostname}
    Serial Number:\t\t\t#{data.serial}
    Model Number:\t\t\t\t#{data.model}
    Software Image:\t\t\t#{data.image}
    Software Version:\t\t#{data.version}
    =====================================================
    Show Inventory
    -----------------------------------------------------
    #{data.sh_inv}
    =====================================================
    Show Version
    -----------------------------------------------------
    #{data.sh_ver}
    =====================================================
    Show Run
    -----------------------------------------------------
    #{data.sh_run}
    =====================================================
    """
    File.write!(data.hostname <> ".txt", content)
  end
end
