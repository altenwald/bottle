import Bottle.Action

action :send_message do
  # IO.puts("#{inspect(data["parent"])} send_message #{inspect(data)}")
  send(data["parent"], {:send_message, data})
end

action :send_prob_message do
  # IO.puts("#{inspect(data["parent"])} send_prob_message #{inspect(data)}")
  send(data["parent"], {:send_prob_message, data})
end
