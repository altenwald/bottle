defmodule Bottle.Bot do
  @moduledoc """
  Bot is a structure in different sections, it's not compulsory to have
  actions or pools, but a complete bot should contains both.

  - Setup. The action(s) triggered at the beginning to prepare the bot.
  - Actions. The actions to be performed proactively. This is based in a
    second frequency and we can define:
    - `run` for constant running each second.
    - `run_prob` for running every second according to probability.
  - Pools. The actions which will be triggered but only if a specific
    stanza is received and matches.

  A bot example for sending and receive messages using message recipts
  (XEP-0184) could be the following one:

  ```elixir
  bot :active_user do
    setup do
      Client.login(data)
    end

    run ~w[ send_message ]a, to: :random
    run_prob {2, 10}, ~w[ offline_online ]a, seconds: 5

    pool ~w[ recv_message ]a, size: 10
  end
  ```

  The definition of the bot is getting performing the setup running the
  `Client.login/1` function and then it's configuring different actions.
  While the `run` and `run_prob` are reviewed every second, the pool is
  launching 10 processes and keeping always 10 processes alive.
  """

  @doc """
  Setup the bot needed infrastructure. Bots uses a `:pg` (process group)
  to get information to know how many bots are running and get a random
  destination for a message.
  """
  @spec setup() :: {:ok, pid()}
  def setup do
    Bottle.Bot.Registry.setup()
    :pg.start_link()
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      use GenServer

      Module.register_attribute(__MODULE__, :run, accumulate: true)
      Module.register_attribute(__MODULE__, :run_prob, accumulate: true)
      Module.register_attribute(__MODULE__, :pools, accumulate: true)

      @before_compile Bottle.Bot

      @default_warmup_time 1_000
      @default_tick_time 1_000

      def bootstrap(data), do: data

      @impl GenServer
      def init([data]) do
        :pg.join(Bottle.Bot, self())
        jid = Bottle.Config.get_jid(data)

        Bottle.Bot.Registry.put(jid)
        {:ok, bootstrap(data), {:continue, :init}}
      end

      @impl GenServer
      def handle_continue(:init, data) do
        data =
          data
          |> then(fn data ->
            Process.sleep(data["warmup_time"] || @default_warmup_time)
            data
          end)
          |> Bottle.Bot.run_pools(__MODULE__)
          |> Bottle.Bot.run_actions(__MODULE__)
          |> Bottle.Bot.run_prob_actions(__MODULE__)

        tick_time = data["tick_time"] || @default_tick_time
        Process.send_after(self(), :tick, tick_time)
        {:noreply, data}
      end

      @impl GenServer
      def handle_info(:tick, data) do
        data =
          data
          |> Bottle.Bot.run_actions(__MODULE__)
          |> Bottle.Bot.run_prob_actions(__MODULE__)

        tick_time = data["tick_time"] || @default_tick_time
        Process.send_after(self(), :tick, tick_time)
        {:noreply, data}
      end

      defoverridable bootstrap: 1
    end
  end

  defp process_options(data, []), do: data

  defp process_options(data, [{:to, :random} | opts]) do
    jid =
      :pg.get_members(Bottle.Bot)
      |> case do
        [_] = pids -> pids
        pids -> List.delete(pids, self())
      end
      |> Enum.random()
      |> Bottle.Bot.Registry.get()

    data
    |> Map.put("to_jid", jid)
    |> process_options(opts)
  end

  defp process_options(data, [{:to, user} | opts]) when is_atom(user) do
    jid = Bottle.Bot.Registry.get(user)

    data
    |> Map.put("to_jid", jid)
    |> process_options(opts)
  end

  defp process_options(data, [{key, value} | opts]) do
    data
    |> Map.put(to_string(key), value)
    |> process_options(opts)
  end

  def start_link(%{} = data, bot_type, bot_name \\ nil) when not is_struct(data) do
    if bot_name do
      GenServer.start_link(to_module(bot_type), [data], name: bot_name)
    else
      GenServer.start_link(to_module(bot_type), [data])
    end
  end

  def stop(bot_name) when is_pid(bot_name) or is_atom(bot_name) do
    GenServer.stop(bot_name)
  end

  def run_actions(data, action_module) do
    action_module.run_actions_info()
    |> Enum.reduce(data, fn {actions, opts}, data_acc ->
      data_acc = process_options(data_acc, opts)
      for action <- actions do
        Bottle.Action.run(data_acc, action)
      end
      data_acc
    end)
  end

  def run_prob_actions(data, action_module) do
    action_module.run_prob_actions_info()
    |> Enum.reduce(data, fn {{prob, max}, actions, opts}, data_acc ->
      data_acc = process_options(data_acc, opts)
      for action <- actions do
        if Enum.random(1..max) <= prob do
          Bottle.Action.run(data_acc, action)
        end
      end
      data_acc
    end)
  end

  def run_pools(data, action_module) do
    action_module.run_pools_info()
    |> Enum.reduce(data, fn {actions, opts}, data_acc ->
      data_acc = process_options(data_acc, opts)
      for action <- actions do
        run = fn ->
          Bottle.Action.run(data_acc, action)
        end
        size = opts[:size]
        # TODO: put in a dynamic supervisor
        Bottle.Bot.Pool.start_link(size: size, run: run)
      end
      data_acc
    end)
  end

  defmacro setup(do: block) do
    quote do
      def bootstrap(data) do
        var!(data) = data
        unquote(block)
      end
    end
  end

  def to_module(name) when is_atom(name) do
    suffix =
      name
      |> to_string()
      |> Macro.camelize()

    Module.concat(Bottle.Bot.Definition, suffix)
  end

  defmacro bot(name, do: block) do
    module = to_module(name)
    quote do
      defmodule unquote(module) do
        @moduledoc false
        use Bottle.Bot

        unquote(block)
      end
    end
  end

  defmacro run(actions, opts) do
    quote do
      @run {unquote(actions), unquote(opts)}
    end
  end

  defmacro run_prob(prob, actions, opts) do
    quote do
      @run_prob {unquote(prob), unquote(actions), unquote(opts)}
    end
  end

  defmacro pool(actions, opts) do
    quote do
      @pools {unquote(actions), unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    run = Module.get_attribute(env.module, :run)
    run_prob = Macro.escape(Module.get_attribute(env.module, :run_prob))
    pools = Module.get_attribute(env.module, :pools)

    quote do
      def run_actions_info, do: unquote(run)
      def run_prob_actions_info, do: unquote(run_prob)
      def run_pools_info, do: unquote(pools)
    end
  end
end
