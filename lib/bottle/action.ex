defmodule Bottle.Action do
  @moduledoc """
  Action is a way to create a script to be followed by the client
  in an asynchronous and non-exclusive way. This means the client
  could be running different actions at the same time and each action
  will keep the track about what's the following thing to be done.

  We can define actions to initiate sending a stanza and then wait
  for a response:

  ```elixir
  action :send_message do
    data
    |> Map.put("message_id", "message1")
    |> Bottle.Client.send_template(:message, to: "juliet@example.com")
    |> Bottle.Client.check!(:receipt, key: "from", timeout: 60_000)
  end
  ```

  In this case the action will be waiting 60 seconds for a receipt once
  the message is sent. We can run as many of these actions as we want.

  We can also start different actions waiting for an incoming message:

  ```elixir
  action :romeo_responses do
    data
    |> check!(:message, timeout: :infinity)
    |> send_template(:receipt, ~w[ conn ])
  end
  ```

  This case the action is adding a check (see `Bottle.Checks`) which
  could be match whenever.

  We can also start a pool of these actions because they are waiting
  for incoming events which match and each event is going to be passed
  to only one check in the waiting list.

  In addition, the function `check!/3` is setting the `:timeout` option
  as `:infinity`. This is meaning the element is never going to be
  removed from the wait list and it's going to be checked for each
  incoming event until one is matching.
  """

  defp to_module(name) do
    name = to_string(name) |> Macro.camelize()
    Module.concat(Bottle.Action, name)
  end

  defmacro action(name, do: block) do
    module = to_module(name)
    quote do
      defmodule unquote(module) do
        @moduledoc false
        use Task
        use Bottle, :bot

        @doc """
        Start the action as a new process.
        """
        def start(data) do
          Task.start(__MODULE__, :run, [data])
        end

        @doc """
        Run in foreground the task. This function is in use
        by `start/1` to launch the task in background.
        """
        def run(data) do
          var!(data) = data
          result = unquote(block)
          Bottle.Stats.notify(:action_success, __MODULE__, result)
        rescue
          error ->
            Bottle.Stats.notify(:action_failure, __MODULE__, error)
            reraise error, __STACKTRACE__
        end
      end
    end
    |> tap(&Bottle.Code.register(&1, module, :action))
  end

  def run(data, name) do
    module = to_module(name)
    module.start(data)
  end
end
