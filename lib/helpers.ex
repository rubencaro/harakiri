
defmodule Harakiri.ActionGroup do
  defstruct paths: [],
            app: nil,
            action: nil,
            lib_path: nil,
            metadata: [loops: 0, hits: 0]
end

defmodule Harakiri.Helpers do

  @doc """
    Convenience to get environment bits. Avoid all that repetitive
    `Application.get_env( :myapp, :blah, :blah)` noise.
  """
  def env(key, default \\ nil), do: env(:harakiri, key, default)
  def env(app, key, default), do: Application.get_env(app, key, default)

  @doc """
    Spit to logger any passed variable, with location information.
  """
  defmacro spit(obj, inspect_opts \\ []) do
    quote do
      %{file: file, line: line} = __ENV__
      [ :bright, :red, "\n\n#{file}:#{line}",
        :normal, "\n\n#{inspect(unquote(obj),unquote(inspect_opts))}\n\n", :reset]
      |> IO.ANSI.format(true) |> IO.puts
    end
  end

  @doc """
    Gets a `Map` and puts it into an `ActionGroup` just the way `Harakiri`
    needs it.

    The `Map` should look like:
    ```
    %{paths: ["file1","file2"], app: :myapp, action: :reload, lib_path: "path"}
    ```
  """
  def digest_data(data) when is_map(data) do
    data = %Harakiri.ActionGroup{} |> Map.merge data # put into an ActionGroup

    # one mtime for each path
    paths = for p <- data.paths, into: [],
      do: [path: p, mtime: get_file_mtime(p)]

    %{data | paths: paths}
  end

  @doc """
    Get the key to be used as on the ETS table
  """
  def get_key(data), do: [data.app, data.action] |> inspect |> to_char_list

  @doc """
    Insert given data into `:harakiri_table`.
    Returns `{:ok, key}` if inserted, `:duplicate` if given data existed.

    If option `:create_paths` is truthy, then it tries to create every path
    in data[:paths]. It returns `{:error, reason}` when that failed.
  """
  def insert(data, opts \\ []) when is_map(data) do
    case opts[:create_paths] && create_paths(data.paths) do
      :ok -> # paths created, need to set initial mtime
        data |> set_initial_mtime |> do_insert
      nil -> do_insert(data) # no create_paths, go on
      x -> x
    end
  end

  defp set_initial_mtime(data) do
    paths = for p <- data.paths, into: [],
              do: [path: p[:path], mtime: get_file_mtime(p[:path])]
    %{data | paths: paths}
  end

  defp do_insert(data) do
    key = get_key(data)
    res = :ets.insert_new(:harakiri_table, {key, data})
    if res, do: {:ok, key}, else: :duplicate
  end

  @doc """
    Insert the given data on the table. Update if it was lready there.
  """
  def upsert(data) when is_map(data) do
    true = :ets.insert(:harakiri_table, {get_key(data), data})
    :ok
  end

  @doc """
    Get first row from the table
  """
  def first, do: lookup(:ets.first(:harakiri_table))

  @doc """
    Get the row for the given key, if it exists. If given key is
    `:"$end_of_table"` it will return `nil`.
  """
  def lookup(:"$end_of_table"), do: nil
  def lookup(key) do
    [{_, data}] = :ets.lookup(:harakiri_table, key)
    data
  end

  @doc """
    Get all rows in the table. This is fine, since we will have little rows.
  """
  def get_chained_next(key, state \\ []) do
    case lookup(key) do
      nil -> state |> Enum.sort
      data -> :ets.next(:harakiri_table, key)
                |> get_chained_next(state ++ [data])
    end
  end

  @doc """
    Get mtime from the OS for the given path
  """
  def get_file_mtime(path) do
    :os.cmd('ls -l --time-style=full-iso #{path}')
    |> to_string |> String.split |> Enum.at(6)
  end

  # Call `create_path/1` for every path in given paths list
  # Return `:ok` if success.
  # Stop looping and return `{:error, reason}` if failed.
  #
  defp create_paths([]), do: :ok
  defp create_paths([path|rest]) do
    case create_path(path[:path]) do
      :ok -> create_paths(rest)
      x -> x
    end
  end

  # Create folders and touch the file for the given path
  # Returns `:ok` or `{:error, reason}`
  #
  defp create_path(path) do
    res = path |> Path.dirname |> File.mkdir_p
    case res do
      :ok -> path |> File.touch
      x -> x
    end
  end
end
