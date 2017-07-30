# Harakiri   腹切

[![Build Status](https://travis-ci.org/rubencaro/harakiri.svg?branch=master)](https://travis-ci.org/rubencaro/harakiri)
[![Hex Version](http://img.shields.io/hexpm/v/harakiri.svg?style=flat)](https://hex.pm/packages/harakiri)
[![Hex Version](http://img.shields.io/hexpm/dt/harakiri.svg?style=flat)](https://hex.pm/packages/harakiri)

`Harakiri` was concieved to help applications kill themselves in response to a `touch` to a file on disk. It grew into something scarier.

Given a list of _files_, an _application_, and an _action_. When any of the files change on disk (i.e. a gentle `touch` is enough), then the given action is fired over the app.

Everything is in an OTP Application so you can have it running in your
system to help all your other applications kill themselves.

Actions can be:

* Any anonymous function.
* `:restart`: Restarts the whole VM, runs `:init.restart`.
* `:stop`: Stops, unloads and deletes app's entry from path.
* `:reload`: like `:stop`, then adds given `lib_path` to path and runs
`Application.ensure_all_started/1`.

## Use

First of all, __add it to your `applications` list__ to ensure it's up before your app starts.

Then add to your `deps` like this:

```elixir
{:harakiri, ">= 1.2.0"}
```

Add an _monitor_ like this:

```elixir
Harakiri.monitor "/path/to/tmp/file", &MyModule.myfun
```

Or an _action group_ like this:

```elixir
Harakiri.add %{paths: ["file1","file2"], action: &MyModule.myfun}
```

You are done. That would run `MyModule.myfun` when `file1` (or `file2`) is touched. All given files (`file1`, `file2`, etc.) must exist, unless you give the option `:create_paths`. Then all given paths will be created if they do not already exist.

## Whole VM restart

If your app is the main one in the Erlang node, then you may consider a whole `:restart`:

```elixir
Harakiri.monitor "/path/to/tmp/restart", :restart
```

That would restart the VM. I.e. stop every application and start them again. __All without stopping the running node__, so it's fast enough for most cases. It tipically takes around one second. See [init.restart/0](http://www.erlang.org/doc/man/init.html#restart-0).

## Anonymous functions

If you need some specific function for your app to be cleanly accessible from outside your VM, then you can pass it as a function. To that function is passed a list with the whole `ActionGroup` and some info on the actual path that fired the event. Like this:

```elixir
myfun = fn(data)->
  # check the exact path that fired
  case data[:file][:path] do
    "/path/to/fire/myfun1" -> do_something1
    "/path/to/fire/myfun2" -> do_something2
  end
  # see all the info you have
  data |> inspect |> Logger.info
end

Harakiri.add %{paths: ["/path/to/fire/myfun1","/path/to/fire/myfun2"],
               action: myfun}
```

This way you can code in pure elixir any complex process you need to perform on a production system. You could perform hot code swaps back and forth between releases of some module, go up&down logging levels, some weird maintenance task, etc. All with a simple `touch` of the right file.

If you perform an `echo` instead of a `touch`, then you could even do something with the contents of the file that fired.

This is quite powerful. Enjoy it.

## Shipped actions

The `:restart` action is suited for a project deployed as the main application in the entire VM. `:init.restart` will kill all applications and then restart them all again.

The `:stop` and `reload` actions are suited for quick operations over a single application, not its dependencies. For instance, `:stop` unloads and deletes the app's entry from path. No other application is stopped and removed from path.

```elixir
Harakiri.monitor "file1", :stop
```

`:reload` will ensure all dependencies are started before the app as it uses `ensure_all_started`, but it will not bother adding them to the path. So any dependency that changed will most probably not start because it will be missing from path.

```elixir
Harakiri.add %{paths: ["file1"],
               action: :reload,
               lib_path: "path"}
```

`lib_path` is the path to the folder containing the `ebin` folder for the current version of the app, usually a link to it. `lib_path` is only needed by `:reload`.

## Demo

[![asciicast](https://asciinema.org/a/18338.png)](https://asciinema.org/a/18338)

## TODOs

* Support for multiple apps on each action set.
* Support for several actions on each action set.
* Deeper test, complete deploy/upgrade/reload simulation

## Changelog

### 1.2.0

* Add `monitor` for simpler use
* Remove Elixir 1.5 warnings

### 1.1.1

* Remove Elixir 1.4 warnings

### 1.1.0

* Add support for async firings
* Make more noise when given function fails

### 1.0.2

* Avoid Elixir 1.3 warnings

### 1.0.1

* Do not touch already existing files on start

### 1.0.0

* Use it on several projects in production without problems
* Avoid race conditions with ETS on testing

### 0.6.0

* Support for anonymous functions as actions

### 0.5.1

* Set initial mtime for created files

### 0.5.0

* Support create paths when asked
* Fix some testing inconsistency

### 0.4.0

* Use ETS to preserve state
* Rearrange using a supervised `Task` for the main loop and regular helpers to access the ETS table. No need for a `GenServer` anymore.

### 0.3.0

* Allow only one instance of the same action group.

### 0.2.0

* First release
