defmodule Bottle.Bot.Stats do
  use GenServer

  @time_to_show 15_000

  defstruct kv: %{}

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  defp transform_values([]) do
    %{min: nil, max: nil, count: 0, avg: nil}
  end
  defp transform_values(values) when is_list(values) do
    {min, max} = Enum.min_max(values)
    count = length(values)
    avg = div(Enum.sum(values), count)
    %{min: min, max: max, count: count, avg: avg}
  end
  defp transform_values(counter) when is_integer(counter) do
    %{count: counter}
  end

  def get_global_stats, do: get_global_stats(get_stats())

  def get_global_stats(stats) do
    Enum.reduce(stats, %{}, fn {_, data}, acc ->
      Enum.reduce(data, acc, fn {key, values}, acc ->
        if key in stats(:duration) do
          Map.update(acc, key, values, & values ++ &1)
        else
          Map.update(acc, key, values, & values + &1)
        end
      end)
    end)
    |> Enum.map(fn {key, values} -> {key, transform_values(values)} end)
    |> Enum.into(%{})
  end

  def get_single_stats, do: get_single_stats(get_stats())

  def get_single_stats(stats) do
    for {pname, data} <- stats, into: %{} do
      data =
        for {key, values} <- data, into: %{}, do: {key, transform_values(values)}
      {pname, data}
    end
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def puts_stats, do: puts_stats(get_stats())

  def puts_stats(stats) do
    stats
    |> get_single_stats()
    |> puts_single_stats()

    stats
    |> get_global_stats()
    |> puts_global_stats()
  end

  def puts_single_stats(single) do
    """
                        | sending   | receive   | login     | chk-ok (us)   | chk-fail (us) |
    --------------------+-----------+-----------+-----------+---------------+---------------+
    """
    |> IO.puts()

    for {name, data} <- single do
      String.pad_leading(to_string(name), 19) <>
        " | " <> String.pad_leading(to_string(data[:sending][:count] || 0), 9) <>
        " | " <> String.pad_leading(to_string(data[:receiving][:count] || 0), 9) <>
        " | " <> String.pad_leading(to_string(data[:login][:count] || 0), 9) <>
        " | " <> String.pad_leading(to_string(data[:checking_success][:avg] || 0), 13) <>
        " | " <> String.pad_leading(to_string(data[:checking_timeout][:avg] || 0), 13) <>
        " |\n"
    end
    |> Enum.join()
    |> IO.puts()
  end

  def puts_global_stats(global) do
    """
    total
    ---------------------
    sending      : #{String.pad_leading(to_string(global[:sending][:count] || 0), 9)}
    receiving    : #{String.pad_leading(to_string(global[:receiving][:count] || 0), 9)}
    logins       : #{String.pad_leading(to_string(global[:login][:count] || 0), 9)}
    checking ok  : #{String.pad_leading(to_string(global[:checking_success][:avg] || 0), 9)}us
    checking fail: #{String.pad_leading(to_string(global[:checking_timeout][:avg] || 0), 9)}us
    """
    |> IO.puts()
  end

  def handle_event(event, measurements, metadata, config) do
    GenServer.cast(__MODULE__, {:event, event, measurements, metadata, config})
  end

  def checking_success(pname, duration, metadata \\ %{}) do
    measurements = %{duration: duration}
    :telemetry.execute([:bottle, pname, :checking_success], measurements, metadata)
  end

  def checking_timeout(pname, duration, metadata \\ %{}) do
    measurements = %{duration: duration}
    :telemetry.execute([:bottle, pname, :checking_failure], measurements, metadata)
  end

  def sending(pname, metadata \\ %{}) do
    meassurements = %{count: 1}
    :telemetry.execute([:bottle, pname, :sending], meassurements, metadata)
  end

  def receiving(pname, metadata \\ %{}) do
    meassurements = %{count: 1}
    :telemetry.execute([:bottle, pname, :receiving], meassurements, metadata)
  end

  def login(pname, metadata \\ %{}) do
    meassurements = %{count: 1}
    :telemetry.execute([:bottle, pname, :login], meassurements, metadata)
  end

  def stats(:all), do: stats(:duration) ++ stats(:counter)
  def stats(:duration), do: ~w[ checking_success checking_timeout ]a
  def stats(:counter), do: ~w[ sending receiving login ]a

  def create_server_events(name) do
    events =
      for key <- stats(:all) do
        [:bottle, name, key]
      end
    :telemetry.attach_many("bot-server-#{name}", events, &handle_event/4, nil)
    GenServer.cast(__MODULE__, {:add, name})
  end

  @impl GenServer
  def init([]) do
    Process.send_after(self(), :stats, @time_to_show)
    {:ok, %__MODULE__{}}
  end

  @impl GenServer
  def handle_info(:stats, state) do
    IO.puts("\n#{IO.ANSI.green_background()}#{IO.ANSI.white()}#{DateTime.utc_now()} ------------------#{IO.ANSI.reset()}")
    state.kv
    |> get_single_stats()
    |> puts_single_stats()
    Process.send_after(self(), :stats, @time_to_show)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, state.kv, state}
  end

  @impl GenServer
  def handle_cast({:add, name}, state) do
    duration_keys =
      for key <- stats(:duration), into: %{}, do: {key, []}
    counter_keys =
      for key <- stats(:counter), into: %{}, do: {key, 0}

    state = put_in(state.kv[name], Map.merge(duration_keys, counter_keys))
    {:noreply, state}
  end
  def handle_cast({:event, [:bottle, pname, key], measurements, _metadata, _config}, state) do
    state =
      cond do
        key in stats(:duration) ->
          update_in(state.kv[pname][key], &[measurements[:duration]|&1])

        key in stats(:counter) ->
          update_in(state.kv[pname][key], & &1 + measurements.count)
      end
    {:noreply, state}
  end
end
