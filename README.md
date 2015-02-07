# Harakiri (BETA)

[![Build Status](https://travis-ci.org/elpulgardelpanda/harakiri.svg?branch=master)](https://travis-ci.org/elpulgardelpanda/harakiri)
[![Hex Version](http://img.shields.io/hexpm/v/harakiri.svg?style=flat)](https://hex.pm/packages/harakiri)

Given a list of _files_, an _application_, and an _action_. When any of the
files change on disk (i.e. a gentle `touch` is enough), then the given action
is fired over the app. `Harakiri` was concieved to help applications kill
themselves in response to a `touch` to a file on disk. Hence the name.

Everything is in an OTP Application so you can have it running in your
system to help all your other applications kill themselves.

Actions can be:

* `:stop`: Stops, unloads and deletes app's entry from path.
* `:reload`: like `:stop`, then adds given `lib_path` to path and runs
`Application.ensure_all_started/1`.
* `:restart`: Restarts the whole VM, runs `:init.restart`.

The `stop` and `reload` actions are suited for quick operations over a single
application, not its dependencies. No other application is stopped and removed
from path. `reload` will ensure all dependencies are started before the app as
it uses `ensure_all_started`, but it will not bother adding them to the path.
So any dependency that changed will most probably not start because it will be
missing from path.

## Use

Add to your `aplications` list to ensure it's up before your app starts.

Add to your `deps` like this:

```elixir
    {:harakiri, github: "elpulgardelpanda/harakiri"}
```

Add an _action group_ like this:

```elixir
    Harakiri.Worker.add %{paths: ["file1","file2"],
                          app: :myapp,
                          action: :reload,
                          lib_path: "path"}
```

You are done. All given files (`file1`, `file2`, etc.) must exist. `lib_path` is
the path to the folder containing the `ebin` folder for the current version of
the app, usually a link to it.

## Demo

http://asciinema.org/a/14617

## TODOs

* Allow only one instance of the same action group.
* Get it stable on production
* Use ETS to preserve state
* Optional creation of watched files.
* Support for multiple apps on each action set.
* Support for several actions on each action set.
* Support for multiple action sets on the same Harakiri process.
* More actions, or even support for funs.
* Deeper test, complete deploy/upgrade/reload simulation
