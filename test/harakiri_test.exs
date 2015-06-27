alias Harakiri, as: Hk
require Harakiri.Helpers, as: H
alias TestHelpers, as: TH

defmodule HarakiriTest do
  use ExUnit.Case, async: false

  test "The supervisor ancestor owns the ETS table" do
    # the table exists
    refute :ets.info(:harakiri_table) == :undefined
    # get the owner
    owner = :ets.info(:harakiri_table)[:owner]
    # get the supervisor ancestor
    info = Process.whereis(Harakiri.Supervisor) |> Process.info
    sup_ancestor = info[:dictionary][:"$ancestors"] |> List.first

    assert owner == sup_ancestor
  end

  test "adds, gets, and clears state" do
    # call it with no state
    :ok = Hk.clear
    # put some state
    data = %Hk.ActionGroup{paths: [], app: :bogus, action: :stop}
    {:ok,_} = Hk.add data
    data2 = %Hk.ActionGroup{paths: [], app: :bogus2, action: :stop}
    {:ok,_} = Hk.add data2
    # the second time it's not duplicated
    :duplicate = Hk.add data
    # check it's there
    assert TH.remove_metadata([data,data2]) == TH.remove_metadata(Hk.state)
    # clear and chek it's gone
    :ok = Hk.clear
    assert [] == Hk.state
  end

  test "fires given action when touching one of given files" do
    # create the watched file
    :os.cmd 'touch /tmp/bogus3'
    # add the ActionGroup
    {:ok, key} = Hk.add %Hk.ActionGroup{paths: ["/tmp/bogus3"], app: :bogus3, action: :stop}
    # also accept as a regular map
    {:ok, key2} = Hk.add %{paths: ["/tmp/bogus4"], app: :bogus4, action: :stop}

    # now it's looping, but no hits for anyone
    for k <- [key,key2] do
      TH.wait_for fn ->
        %{metadata: md} = H.lookup(k)
        md[:loops] > 0 and md[:hits] == 0
      end
    end

    # touch file
    :os.cmd 'touch /tmp/bogus3'

    # now bogus it's been fired once
    TH.wait_for fn ->
      %{metadata: md} = H.lookup(key)
      md[:loops] > 0 and md[:hits] == 1
    end

    # not the second bogus
    TH.wait_for fn ->
      %{metadata: md} = H.lookup(key2)
      md[:loops] > 0 and md[:hits] == 0
    end
  end

  test "creates nonexistent watched paths if asked" do
    paths = ["/tmp/bogus51","/tmp/bogus52"]

    # ensure each file does not exist
    for p <- paths, do: File.rm(p)

    # add the ActionGroup passing `create_paths`
    {:ok, _} = Hk.add %{paths: paths, app: :bogus5, action: :stop}, [create_paths: true]

    # assert they exist now
    for p <- paths, do: assert File.exists?(p)
  end

  test "stop does not crash" do
    ag = %{paths: ["/tmp/bogus"], app: :bogus, action: :stop} |> H.digest_data
    :ok = Hk.Worker.fire :stop, ag
  end

  test "reload does not crash" do
    ag = %{paths: ["/tmp/bogus"], app: :bogus, action: :reload} |> H.digest_data
    :ok = Hk.Worker.fire :reload, ag
  end

end
