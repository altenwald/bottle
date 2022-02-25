defmodule Bottle.ActionTest do
  use ExUnit.Case

  import Bottle.Action, only: [action: 2]
  alias Bottle.Action

  test "create action" do
    action :romeo_response do
      send(data["process_name"], :done)
    end

    assert function_exported?(Bottle.Action.RomeoResponse, :run, 1)
    assert {:ok, pid} = Action.run(%{"process_name" => self()}, :romeo_response)
    assert is_pid(pid)
    assert_receive :done
  end
end
