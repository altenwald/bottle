defmodule Bottle.Bot.PoolTest do
  use ExUnit.Case

  alias Bottle.Bot.Pool

  setup do
    run = fn ->
      # see actions is test/support/actions.ex
      Bottle.Action.run(%{}, :receive_ok)
    end
    {:ok, pool} = Pool.start_link(size: 10, run: run)
    %{pool: pool}
  end

  test "check always 10 processes are running", %{pool: pool} do
    assert [pid | other_pids] = pids = Pool.get_pids(pool)
    assert 10 == length(pids)
    send(pid, :ok)
    Process.sleep(100)
    assert [new_pid | ^other_pids] = pids = Pool.get_pids(pool)
    refute pid == new_pid
    assert 10 == length(pids)
  end
end
