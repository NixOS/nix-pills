# Nixpkgs Parameters

Welcome to the 16th Nix pill. In the previous [15th](15-nix-search-paths.md) pill we've realized how nix finds expressions with the angular brackets syntax, so that we finally know where `<nixpkgs>` is located on our system.

We can start diving into the [nixpkgs repository](https://github.com/NixOS/nixpkgs), through all the various tools and design patterns. Please note that also `nixpkgs` has its own manual, underlying the difference between the general `nix` language and the `nixpkgs` repository.

## The default.nix expression

We will not start inspecting packages at the beginning, rather the general structure of `nixpkgs`.

In our custom repository we created a `default.nix` which composed the expressions of the various packages.

Also `nixpkgs` has its own [default.nix](https://github.com/NixOS/nixpkgs/blob/master/default.nix), which is the one being loaded when referring to `<nixpkgs>`. It does a simple thing: check whether the `nix` version is at least 1.7 (at the time of writing this blog post). Then import [pkgs/top-level/all-packages.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/all-packages.nix). From now on, we will refer to this set of packages as **pkgs**.

The `all-packages.nix` is then the file that composes all the packages. Note the `pkgs/` subdirectory, while nixos is in the `nixos/` subdirectory.

The `all-packages.nix` is a bit contrived. First of all, it's a function. It accepts a couple of interesting parameters:

- `system`: defaults to the current system

- `config`: defaults to null

- others...

The **system** parameter, as per comment in the expression, it's the system for which the packages will be built. It allows for example to install i686 packages on amd64 machines.

The **config** parameter is a simple attribute set. Packages can read some of its values and change the behavior of some derivations.

## The system parameter

You will find this parameter in many other .nix expressions (e.g. release expressions). The reason is that, given pkgs accepts a system parameter, then whenever you want to import pkgs you also want to pass through the value of system. E.g.:

`myrelease.nix`:

```nix
{ system ? builtins.currentSystem }:

let pkgs = import <nixpkgs> { inherit system; };
...
```

Why is it useful? With this parameter it's very easy to select a set of packages for a particular system. For example:

```console
nix-build -A psmisc --argstr system i686-linux
```

This will build the `psmisc` derivation for i686-linux instead of x86_64-linux. This concept is very similar to multi-arch of Debian.

The setup for cross compiling is also in `nixpkgs`, however it's a little contrived to talk about it and I don't know much of it either.

## The config parameter

I'm sure on the wiki or other manuals you've read about `~/.config/nixpkgs/config.nix` (previously `~/.nixpkgs/config.nix`) and I'm sure you've wondered whether that's hardcoded in nix. It's not, it's in [nixpkgs](https://github.com/NixOS/nixpkgs/blob/32c523914fdb8bf9cc7912b1eba023a8daaae2e8/pkgs/top-level/impure.nix#L28).

The `all-packages.nix` expression accepts the `config` parameter. If it's `null`, then it reads the `NIXPKGS_CONFIG` environment variable. If not specified, `nixpkgs` will pick `$HOME/.config/nixpkgs/config.nix`.

After determining `config.nix`, it will be imported as a nix expression, and that will be the value of `config` (in case it hasn't been passed as parameter to import `<nixpkgs>`).

The `config` is available in the resulting repository:

```console
$ nix repl
nix-repl> pkgs = import <nixpkgs> {}
nix-repl> pkgs.config
{ }
nix-repl> pkgs = import <nixpkgs> { config = { foo = "bar"; }; }
nix-repl> pkgs.config
{ foo = "bar"; }
```

What attributes go in `config` is a matter of convenience and conventions.

For example, `config.allowUnfree` is an attribute that forbids building packages that have an unfree license by default. The `config.pulseaudio` setting tells whether to build packages with `pulseaudio` support or not where applicable and when the derivation obeys to the setting.

## About .nix functions

A `.nix` file contains a nix expression. Thus it can also be a function. I remind you that `nix-build` expects the expression to return a derivation. Therefore it's natural to return straight a derivation from a `.nix` file. However, it's also very natural for the `.nix` file to accept some parameters, in order to tweak the derivation being returned.

In this case, nix does a trick:

- If the expression is a derivation, build it.

- If the expression is a function, call it and build the resulting derivation.

For example you can nix-build the `.nix` file below:

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.psmisc
```

Nix is able to call the function because the pkgs parameter has a default value. This allows you to pass a different value for pkgs using the `--arg` option.

Does it work if you have a function returning a function that returns a derivation? No, Nix only calls the function it encounters once.

## Conclusion

We've unleashed the `<nixpkgs>` repository. It's a function that accepts some parameters, and returns the set of all packages. Due to laziness, only the accessed derivations will be built.

You can use this repository to build your own packages as we've seen in the previous pill when creating our own repository.

Lately I'm a little busy with the NixOS 14.11 release and other stuff, and I'm also looking toward migrating from blogger to a more coder-oriented blogging platform. So sorry for the delayed and shorter pills :)

## Next pill

...we will talk about overriding packages in the `nixpkgs` repository. What if you want to change some options of a library and let all other packages pick the new library? One possibility is to use, like described above, the `config` parameter when applicable. The other possibility is to override derivations.
