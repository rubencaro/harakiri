alias Harakiri.Worker
alias Harakiri.ActionGroup

defmodule HarakiriTest do
  use ExUnit.Case, async: true

  test "adds, gets, and clears state" do
    # call it with no state
    :ok = Worker.clear
    # put some state
    data = %ActionGroup{paths: [], app: :bogus, action: :stop}
    :ok = Worker.add data
    # check it's there
    assert [data] == Worker.state
    # clear and chek it's gone
    :ok = Worker.clear
    assert [] == Worker.state
  end

  test "fires given action when touching one of given files" do
    # setup ActionGroup
    :os.cmd 'touch /tmp/bogus' # create it
    :ok = Worker.add %ActionGroup{paths: ["/tmp/bogus"], app: :bogus, action: :stop}
    # now it's looping

    # touch file
    :os.cmd 'touch /tmp/bogus'

    # now it's been fired
  end

end
