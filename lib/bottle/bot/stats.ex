defmodule Bottle.Bot.Stats do
  use GenServer

  require Logger

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
    avg = Enum.sum(values) / count
    %{min: min, max: max, count: count, avg: avg}
  end
  defp transform_values(counter) when is_integer(counter) do
    %{count: counter}
  end

  def get_stats do
    stats = GenServer.call(__MODULE__, :get_stats)
    single =
      for {pname, data} <- stats, into: %{} do
        data =
          for {key, values} <- data, into: %{}, do: {key, transform_values(values)}
        {pname, data}
      end

    global =
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

    {single, global}
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
    {:ok, %__MODULE__{}}
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
  def handle_cast({:event, [:bottle, pname, key], measurements, metadata, _config}, state) do
    event = "bottle:#{pname}:#{key}"
    Logger.notice("#{event} #{inspect(measurements)} #{inspect(metadata)}")
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
