defmodule Bottle.ChecksTest do
  use ExUnit.Case

  alias Bottle.Checks

  setup do
    Checks.setup(Path.join(__DIR__, "checks.exs"))
  end

  test "start and stop" do
    {:ok, pid} = Checks.start_link(:test_checks, self())
    assert_receive {:"$gen_cast", {:trace, ^pid, true}}
    :ok = Checks.stop(:test_checks)
  end

  describe "receive and check events" do
    setup do
      Checks.setup(Path.join(__DIR__, "checks.exs"))
      {:ok, pid} = Checks.start_link(:test_checks, self(), 5)
      assert_receive {:"$gen_cast", {:trace, ^pid, true}}

      %{pid: pid}
    end

    test "sending events", %{pid: pid} do
      send(pid, {:received, self(), conn: :match1})
      assert %Checks{events: [{:received, _pid, conn: :match1}]} = :sys.get_state(pid)
    end

    test "register check" do
      assert :ok = Checks.put(:check1, fn(_event, _options) -> :ok end)
      assert is_function(f = Checks.get(:check1), 2)
      assert :ok = f.(nil, nil)
    end

    test "check empty events and no options", %{pid: pid} do
      assert :ok = Checks.put(:check2, fn(_event, [option1: :value1]) -> :correct end)
      assert {:error, :no_match} = Checks.validate(pid, :check2)
    end

    test "check empty events and timeout option", %{pid: pid} do
      assert :ok = Checks.put(:check2, fn(_event, [option1: :value1]) -> :correct end)
      assert {:error, :timeout} = Checks.validate(pid, :check2, timeout: 100)
    end

    test "check available event", %{pid: pid} do
      assert :ok = Checks.put(:check2, fn(_event, option1: :value1) -> :correct end)
      send(pid, {:received, self(), [data1: :value1]})
      assert {:ok, {:correct, {:received, _, _}}} = Checks.validate(pid, :check2, option1: :value1)
    end

    test "check available event with timeout option", %{pid: pid} do
      assert :ok = Checks.put(:check2, fn(_event, timeout: 500) -> :correct end)
      send(pid, {:received, self(), [data1: :value1]})
      assert {:ok, {:correct, {:received, _, _}}} = Checks.validate(pid, :check2, timeout: 500)
    end

    test "check awaiting for incoming event", %{pid: pid} do
      assert :ok = Checks.put(:check2, fn(_event, [option1: :value1, timeout: 500]) -> :correct end)
      Process.send_after(pid, {:received, self(), [data1: :value1]}, 250)
      assert {:ok, {:correct, {:received, _, _}}} = Checks.validate(pid, :check2, option1: :value1, timeout: 500)
    end
  end
end
