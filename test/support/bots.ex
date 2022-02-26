import Bottle.Bot

# using actions from test/support/actions.ex

bot :active_user do
  setup do
    # IO.puts("#{inspect(data["parent"])} setup #{inspect(data)}")
    send(data["parent"], {:setup, data})
    data
  end
  Bottle.Bot.run ~w[ send_message ]a, to: :random
  Bottle.Bot.run_prob {2, 10}, ~w[ send_prob_message ]a, to: :random
end
