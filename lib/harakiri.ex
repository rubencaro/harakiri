require Harakiri.Helpers, as: H

defmodule Harakiri do
  use Application

  @doc """
    Start and supervise a single lonely worker
  """
  def start(_,_) do
    import Supervisor.Spec, warn: false

    # start ETS named_table from here,
    # thus make it persistent as long as the VM runs (Harakiri should be `permanent`...)
    :ets.new(:harakiri_table, [:public,:set,:named_table])

    loop_sleep_ms = Application.get_env(:harakiri, :loop_sleep_ms, 5_000)

    opts = [strategy: :one_for_one, name: Harakiri.Supervisor]
    Supervisor.start_link([ worker(Task, [Harakiri.Worker,:loop,[loop_sleep_ms]]) ], opts)
  end

  @doc """
    Add given data as an _action group_. It should be a `Map`.
    ```
    Harakiri.add %{paths: ["file1","file2"],
                   app: :myapp,
                   action: :reload,
                   lib_path: "path"}
    ```
  """
  def add(data) when is_map(data) do
    data |> H.digest_data |> H.insert
  end

  @doc """
    Get/set all Harakiri state
  """
  def state do
    :ets.all(:harakiri_table) |> Enum.map( fn({_,data})-> data end)
  end
  def state(data), do: for( d <- data, do: H.insert d )

  @doc """
    Clear all Harakiri state
  """
  def clear, do: :ets.delete_all_objects(:harakiri_table)
end

defmodule Harakiri.Worker do

  @doc """
    Perform harakiri if given file is touched. Else keep an infinite loop
    sleeping given msecs each time.
  """
  def loop(sleep_ms) do
    for ag <- Harakiri.state, into: [] do

      # check every path
      checked_paths = for p <- ag.paths, into: [] do
        new_mtime = check_file(p,ag)
        [path: p[:path], mtime: new_mtime, hit: p[:mtime] != new_mtime]
      end

      # save new mtimes
      paths = for p <- checked_paths, into: [], do: [path: p[:path], mtime: p[:mtime]]

      # update metadata
      md = ag.metadata
      hit = Enum.reduce(checked_paths, false, fn(p,acc) -> p[:hit] or acc end)
      if hit, do: md = Keyword.put(md, :hits, md[:hits] + 1)
      md = Keyword.put(md, :loops, md[:loops] + 1)

      %{ ag | paths: paths, metadata: md }
    end |> Harakiri.state

    :timer.sleep sleep_ms
    loop sleep_ms
  end

  defp check_file(path, ag) do
    new_mtime = get_file_mtime path[:path]
    if path[:mtime] && (path[:mtime] != new_mtime) do
      fire(ag.action, ag)
    end
    new_mtime
  end

  defp get_file_mtime(path) do
    :os.cmd('ls -l --time-style=full-iso #{path}')
    |> to_string |> String.split |> Enum.at(6)
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
