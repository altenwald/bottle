defmodule Bottle.BotTest do
  use ExUnit.Case

  require Bottle.Bot
  alias Bottle.{Bot, Client}

  setup do
    assert {:ok, _pid} = Bot.setup()
    :ok
  end

  test "support bot check" do
    # see test/support/bots.ex
    assert %{} = data_user1 = Client.config(Path.join(__DIR__, "user1.exs"))
    assert %{} = data_user2 = Client.config(Path.join(__DIR__, "user2.exs"))
    data_user1 = Map.put(data_user1, "parent", self())
    data_user2 = Map.put(data_user2, "parent", self())
    assert {:ok, bot1} = Bot.start_link(data_user1, :active_user, :bot1)
    assert {:ok, bot2} = Bot.start_link(data_user2, :active_user)
    assert_receive {:setup, %{"process_name" => :user1}}
    assert_receive {:setup, %{"process_name" => :user2}}

    jid1 = Bottle.Bot.get_jid(data_user1)
    jid2 = Bottle.Bot.get_jid(data_user2)

    assert_receive {:send_message, %{"process_name" => :user1, "to_jid" => jid}} when jid in [jid1, jid2], 5_000
    assert_receive {:send_message, %{"process_name" => :user2, "to_jid" => jid}} when jid in [jid1, jid2], 5_000
    assert_receive {:send_message, %{"process_name" => :user1, "to_jid" => jid}} when jid in [jid1, jid2], 5_000
    assert_receive {:send_message, %{"process_name" => :user2, "to_jid" => jid}} when jid in [jid1, jid2], 5_000

    assert_receive {:send_prob_message, %{"process_name" => :user1, "to_jid" => jid}} when jid in [jid1, jid2], 5_000
    assert_receive {:send_prob_message, %{"process_name" => :user2, "to_jid" => jid}} when jid in [jid1, jid2], 5_000

    Bot.stop(bot1)
    Bot.stop(bot2)
    clean_messages()
  end

  defp clean_messages do
    receive do
      _ -> clean_messages()
    after
      0 -> :ok
    end
  end
end
