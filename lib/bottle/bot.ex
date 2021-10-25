defmodule Bottle.Bot do
  @moduledoc """
  The Bot let us define a behaviour which could be loaded from scenarios.
  The difference with the normal scenarios is the bot is defining when it's
  finalizing and defines a way to continue working into a loop.

  The way to define the behaviour is based on the following configurations:

  - `:sequential`: all of the sentences are running in perfect order, one by
    one. When the sequence is finished, it start from the beginning again
    until one of the exit premises is acomplished.
  - `:random`: the list of elements is shuffle before start with them. However,
    the bot is ensuring of running all of them until start a new loop.
  - `:chaotic`: completely random. But also it's adding random delays between
    orders ensuring all of them are coming when you are not expecting them!

  The exit premises could be defined to finish based on:

  - `:once`: it's running only once. Exactly the same as scenarios.
  - `{:times, pos_integer()}`: defines the exact number of times it is running.
  - `:infinity`: it's not stopping.
  - `{:duration, pos_integer()}`: number of seconds it should be running.
  """

  defmacro bot(name, do: block) do
    camelize_name =
      to_string(name)
      |> Macro.camelize()

    module_name = Module.concat([__MODULE__, Agent, camelize_name])
    quote do
      defmodule unquote(module_name) do

        Module.register_attribute(__MODULE__, :bot_data, accumulate: true)
        Module.register_attribute(__MODULE__, :run_action, accumulate: true)
        Module.register_attribute(__MODULE__, :step_action, accumulate: true)
        Module.register_attribute(__MODULE__, :inside_action, accumulate: true)
        @step_block false
        @run_block false

        unquote(block)

        def id(), do: unquote(name)

        def data, do: data(@bot_data)

        def data(bot_data) when is_list(bot_data) do
          Enum.into(bot_data, %{})
          |> Map.put("process_name", unquote(name))
        end

        def actions(), do: Enum.reverse(@run_action)
      end
      Bottle.Bot.Supervisor.start_child(unquote(name), unquote(module_name))
    end
  end

  defmacro show_stats([for: names]) do
    quote do
      unquote(names)
      |> Enum.map(fn name ->
        Bottle.Bot.Server.wait_for(false, name, 10_000)
        pid = Process.whereis(name)
        mon_ref = Process.monitor(pid)
        {pid, mon_ref}
      end)
      |> Enum.each(fn {pid, mon_ref} ->
        receive do
          {:DOWN, ^mon_ref, :process, ^pid, _reason} -> :ok
        end
      end)
      IO.puts("\n#{IO.ANSI.green_background()}#{IO.ANSI.white()} END  ----------------------- #{IO.ANSI.reset()}")
      Bottle.Bot.Stats.puts_stats()
    end
  end

  defmacro set([{name, value}]) when is_atom(name) do
    quote do
      @bot_data {to_string(unquote(name)), unquote(value)}
    end
  end

  defmacro set_from_file(file) when is_binary(file) do
    {%{} = data, []} = Code.eval_file(file)
    data = Map.to_list(data)
    quote do
      for {key, value} <- unquote(data), do: @bot_data {key, value}
    end
  end

  defmacro set([{name, value}]) when is_function(name, 1) do
    quote do
      data = @bot_data
      @bot_data {to_string(unquote(name)), unquote(value).(data)}
    end
  end

  defmacro login() do
    quote do
      login_fun = {Bottle.Client, :login, []}

      if @run_block do
        if @step_block do
          @inside_action login_fun
        else
          @step_action {:login, [optional: false], [login_fun]}
        end
      else
        @run_action {[], [{:login, [optional: false], [login_fun]}]}
      end
    end
  end

  defmacro logout() do
    quote do
      logout_fun = {Bottle.Client, :disconnect, []}

      if @run_block do
        if @step_block do
          @inside_action logout_fun
        else
          @step_action {:logout, [optional: false], [logout_fun]}
        end
      else
        @run_action {[], [{:logout, [optional: false], [logout_fun]}]}
      end
    end
  end

  defmacro wait_for(bot, timeout \\ 60_000) when is_atom(bot) do
    quote do
      wait_for_fun = {Bottle.Bot.Server, :wait_for, [unquote(bot), unquote(timeout)]}

      if @run_block do
        if @step_block do
          @inside_action wait_for_fun
        else
          @step_action {:wait_for, [optional: false], [wait_for_fun]}
        end
      else
        @run_action {[], [{:wait_for, [optional: false], [wait_for_fun]}]}
      end
    end
  end

  def wait(data, time) do
    Process.sleep(time)
    data
  end

  defmacro wait(milliseconds) when is_integer(milliseconds) do
    quote do
      wait_fun = {Bottle.Bot, :wait, [unquote(milliseconds)]}

      if @run_block do
        if @step_block do
          @inside_action wait_fun
        else
          @step_action {:wait, [optional: false], [wait_fun]}
        end
      else
        @run_action {[], [{:wait, [optional: false], [wait_fun]}]}
      end
    end
  end

  defmacro run(options, do: block) do
    quote do
      @run_block true
      Module.delete_attribute(__MODULE__, :step_action)
      Module.register_attribute(__MODULE__, :step_action, accumulate: true)
      unquote(block)
      @run_action {unquote(options), Enum.reverse(@step_action)}
      @run_block false
    end
  end

  defmacro step(name, do: block) do
    quote do
      @step_block true
      Module.delete_attribute(__MODULE__, :inside_action)
      Module.register_attribute(__MODULE__, :inside_action, accumulate: true)
      unquote(block)
      data =
        if @run_block do
          @step_action {unquote(name), [optional: false], Enum.reverse(@inside_action)}
        else
          @run_action {unquote(name), [optional: false], Enum.reverse(@inside_action)}
        end
      @step_block false
      data
    end
  end

  defmacro maybe(name, do: block) do
    quote do
      @step_block true
      Module.delete_attribute(__MODULE__, :inside_action)
      Module.register_attribute(__MODULE__, :inside_action, accumulate: true)
      unquote(block)
      data =
        if @run_block do
          @step_action {unquote(name), [optional: true], Enum.reverse(@inside_action)}
        else
          @run_action {unquote(name), [optional: true], Enum.reverse(@inside_action)}
        end
      @step_block false
      data
    end
  end

  defmacro sending(name, options \\ []) do
    quote do
      if @step_block and @run_block do
        @inside_action {Bottle.Bot.Server, :sending, [unquote(name), unquote(options)]}
      else
        raise """
        Bottle.Bot.sending/2 requires to run inside of a run and step context.
        """
      end
    end
  end

  defmacro checking(name, options \\ []) do
    quote do
      if @step_block and @run_block do
        @inside_action {Bottle.Bot.Server, :checking, [unquote(name), unquote(options)]}
      else
        raise """
        Bottle.Bot.checking/2 requires to run inside of a run and step context.
        """
      end
    end
  end
end
