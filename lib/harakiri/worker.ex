require Harakiri.Helpers, as: H
alias Harakiri, as: Hk
alias Keyword, as: K

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
      md = if Enum.any?(checked_paths, &(&1[:hit])), # if any path was hit
            do: K.put(md, :hits, md[:hits] + 1), # +1 hits
            else: md

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
      do: fire(ag.action, ag: ag, file: path)
    new_mtime
  end

  @doc """
    Fire the `:stop` callback for the given ActionGroup
  """
  def fire(:stop, data) do
    ag = data[:ag]
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
  def fire(:reload, data) do
    ag = data[:ag]
    :ok = fire :stop, data
    res = :code.add_patha('#{ag.lib_path}/ebin')
    IO.puts "Added to path #{ag.app}... #{inspect res}"
    res = Application.ensure_all_started ag.app
    IO.puts "Started #{ag.app}... #{inspect res}"
    :ok
  end

  @doc """
    Fire the `:restart` callback for the given ActionGroup
  """
  def fire(:restart, _data) do
    res = :init.restart
    IO.puts "Scheduled system restart... #{inspect res}"
    :ok
  end

  @doc """
    Fire the given anonymous function for the given ActionGroup
  """
  def fire(fun, data) when is_function(fun) do
    Task.start_link(fn ->
      try do
        IO.puts "Running requested function..."
        res = fun.(data)
        IO.puts "Ran requested function: #{inspect res}"
      rescue
        x -> IO.puts "Error running requested function: #{inspect x}, backtrace: #{inspect System.stacktrace}"
      catch
        x -> IO.puts "Error running requested function: #{inspect x}"
      end
    end)

    :ok
  end

end
