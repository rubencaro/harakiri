require Harakiri.Helpers, as: H
alias Harakiri, as: Hk
alias Keyword, as: K

defmodule Harakiri do
  use Application

  @doc """
    Start and supervise a single lonely worker
  """
  def start(_,_) do
    import Supervisor.Spec

    # start ETS named_table from here,
    # thus make it persistent as long as the VM runs (Harakiri should be `permanent`...)
    :ets.new(:harakiri_table, [:public,:set,:named_table])

    loop_sleep_ms = H.env(:loop_sleep_ms, 5_000)

    opts = [strategy: :one_for_one, name: Hk.Supervisor]
    children = [ worker(Task, [Hk.Worker,:loop,[loop_sleep_ms]]) ]
    Supervisor.start_link(children, opts)
  end

  @doc """
    Add given `Map` as an `Harakiri.ActionGroup`.
    See README or tests for examples.
  """
  def add(data, opts \\ []) when is_map(data), do: data |> H.digest_data |> H.insert(opts)

  @doc """
    Get/set all Harakiri state
  """
  def state, do: :ets.first(:harakiri_table) |> H.get_chained_next
  def state(data), do: for( d <- data, do: :ok = H.upsert(d) )

  @doc """
    Clear all Harakiri state
  """
  def clear do
    true = :ets.delete_all_objects(:harakiri_table)
    :ok
  end
end

defmodule Harakiri.Worker do

  @doc """
    Perform requested action if any given path is touched.
    Else keep an infinite loop sleeping given msecs each time.
  """
  def loop(sleep_ms) do

    # go over every ag and update them
    updated_ags = for ag <- Hk.state, into: [] do

      # check every path, calc new mtimes and metadata
      checked_paths = for p <- ag.paths, into: [] do
        new_mtime = check_file(p,ag)
        [path: p[:path], mtime: new_mtime, hit: p[:mtime] != new_mtime]
      end

      # save new mtimes for paths
      paths = for p <- checked_paths, into: [],
                do: [path: p[:path], mtime: p[:mtime]]

      # update metadata
      md = ag.metadata
      md = K.put(md, :loops, md[:loops] + 1) # +1 loops
      if Enum.any?(checked_paths, &(&1[:hit])), # if any path was hit
        do: md = K.put(md, :hits, md[:hits] + 1) # +1 hits

      # update ag's data
      %{ ag | paths: paths, metadata: md }
    end

    # replace old ags with the new ones
    Hk.state updated_ags

    # sleep and loop
    :timer.sleep sleep_ms
    loop sleep_ms
  end

  # Fire the corresponding function if any mtime changed
  #
  defp check_file(path, ag) do
    new_mtime = H.get_file_mtime path[:path]
    if path[:mtime] && (path[:mtime] != new_mtime),
      do: fire(ag.action, ag)
    new_mtime
  end

  @doc """
    Fire the `:stop` callback for the given ActionGroup
  """
  def fire(:stop, ag) do
    res = Application.stop(ag.app)
    IO.puts "Stopped #{ag.app}... #{inspect res}"
    res = Application.unload ag.app
    IO.puts "Unloaded #{ag.app}... #{inspect res}"
    res = :code.del_path(ag.app)
    IO.puts "Removed from path #{ag.app}... #{inspect res}"
    :ok
  end

  @doc """
    Fire the `:reload` callback for the given ActionGroup
  """
  def fire(:reload, ag) do
    :ok = fire :stop, ag
    res = :code.add_patha('#{ag.lib_path}/ebin')
    IO.puts "Added to path #{ag.app}... #{inspect res}"
    res = Application.ensure_all_started ag.app
    IO.puts "Started #{ag.app}... #{inspect res}"
    :ok
  end

  @doc """
    Fire the `:restart` callback for the given ActionGroup
  """
  def fire(:restart, _ag) do
    res = :init.restart
    IO.puts "Scheduled system restart... #{inspect res}"
    :ok
  end
end
