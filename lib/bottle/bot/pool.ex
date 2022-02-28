defmodule Bottle.Bot.Pool do
  @moduledoc """
  Create a pool of processes and ensure the number of available
  processes is always the same.
  """
  use GenServer

  @default_size 5

  defstruct size: 0,
            pool: [],
            run: nil

  @type t() :: %__MODULE__{
    size: non_neg_integer(),
    pool: [{reference(), pid()}],
    run: (() -> {:ok, pid()}) | nil
  }

  @doc """
  Start the pool. This is requiring a list of options where you can use the
  following options:

  - `run`: an anonymous function without arguments (zero arity).
  - `size`: the number of elements we have to keep.
  """
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Get pids inside of the pool.
  """
  @spec get_pids(pid) :: [pid()]
  def get_pids(pid) do
    GenServer.call(pid, :get_pids)
  end

  @impl GenServer
  def init(opts) do
    size = opts[:size] || @default_size
    run = opts[:run]
    pool = for _ <- 1..size, do: exec(run)

    {:ok, %__MODULE__{
      size: size,
      pool: pool,
      run: run
    }}
  end

  defp exec(run) do
    {:ok, pid} = run.()
    ref = Process.monitor(pid)
    {ref, pid}
  end

  @impl GenServer
  def handle_call(:get_pids, _from, state) do
    {:reply, Enum.map(state.pool, fn {_ref, pid} -> pid end), state}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    pool = [exec(state.run) | List.delete(state.pool, {ref, pid})]
    {:noreply, %__MODULE__{state | pool: pool}}
  end
end
