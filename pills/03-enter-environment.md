# Enter the Environment {#enter-environment}

Welcome to the third Nix pill. In the [second pill](02-install-on-your-running-system.md) we installed Nix on our running system. Now we can finally play with it a little, these things also apply to NixOS users.

## Enter the environment

**If you're using NixOS, you can skip to the [next](#install-something) step.**

In the previous article we created a Nix user, so let's start by switching to it with `su - nix`. If your `~/.profile` got evaluated, then you should now be able to run commands like `nix-env` and `nix-store`.

If that's not the case:

```console
$ source ~/.nix-profile/etc/profile.d/nix.sh
```

To remind you, `~/.nix-profile/etc` points to the `nix-2.1.3` derivation. At this point, we are in our Nix user profile.

## Install something {#install-something}

Finally something practical! Installation into the Nix environment is an interesting process. Let's install `hello`, a simple CLI tool which prints `Hello world` and is mainly used to test compilers and package installations.

Back to the installation:

```console
$ nix-env -i hello
installing 'hello-2.10'
[...]
building '/nix/store/0vqw0ssmh6y5zj48yg34gc6macr883xk-user-environment.drv'...
created 36 symlinks in user environment
```

Now you can run `hello`. Things to notice:

- We installed software as a user, and only for the Nix user.

- It created a new user environment. That's a new generation of our Nix user profile.

- The [nix-env](https://nix.dev/manual/nix/stable/command-ref/nix-env) tool manages environments, profiles and their generations.

- We installed `hello` by derivation name minus the version. I repeat: we specified the **derivation name** (minus the version) to install it.

We can list generations without walking through the `/nix` hierarchy:

```console
$ nix-env --list-generations
    1   2014-07-24 09:23:30
    2   2014-07-25 08:45:01   (current)
```

Listing installed derivations:

```console
$ nix-env -q
nix-2.1.3
hello-2.10
```

So, where did `hello` really get installed? `which hello` is `~/.nix-profile/bin/hello` which points to the store. We can also list the derivation paths with `nix-env -q --out-path`. So that's what those derivation paths are called: the **output** of a build.

## Path merging

At this point you probably want to run `man` to get some documentation. Even if you already have man system-wide outside of the Nix environment, you can install and use it within Nix with `nix-env -i man-db`. As usual, a new generation will be created, and `~/.nix-profile` will point to it.

Let's inspect the [profile](https://nix.dev/manual/nix/stable/package-management/profiles) a bit:

```console
$ ls -l ~/.nix-profile/
dr-xr-xr-x 2 nix nix 4096 Jan  1  1970 bin
lrwxrwxrwx 1 nix nix   55 Jan  1  1970 etc -> /nix/store/ig31y9gfpp8pf3szdd7d4sf29zr7igbr-nix-2.1.3/etc
[...]
```

Now that's interesting. When only `nix-2.1.3` was installed, `bin` was a symlink to `nix-2.1.3`. Now that we've actually installed some things (`man`, `hello`), it's a real directory, not a symlink.

```console
$ ls -l ~/.nix-profile/bin/
[...]
man -> /nix/store/83cn9ing5sc6644h50dqzzfxcs07r2jn-man-1.6g/bin/man
[...]
nix-env -> /nix/store/ig31y9gfpp8pf3szdd7d4sf29zr7igbr-nix-2.1.3/bin/nix-env
[...]
hello -> /nix/store/58r35bqb4f3lxbnbabq718svq9i2pda3-hello-2.10/bin/hello
[...]
```

Okay, that's clearer now. `nix-env` merged the paths from the installed derivations. `which man` points to the Nix profile, rather than the system `man`, because `~/.nix-profile/bin` is at the head of `$PATH`.

## Rolling back and switching generation

The last command installed `man`. We should be at generation 3, unless you changed something in the middle. Let's say we want to rollback to the old generation:

```console
$ nix-env --rollback
switching from generation 3 to 2
```

Now `nix-env -q` does not list `man` anymore. `` ls -l `which man` `` should now be your system copy.

Enough with the rollback, let's go back to the most recent generation:

```console
$ nix-env -G 3
switching from generation 2 to 3
```

I invite you to read the manpage of `nix-env`. `nix-env` requires an operation to perform, then there are common options for all operations, as well as options specific to each operation.

You can of course also [uninstall](https://nix.dev/manual/nix/stable/command-ref/nix-env/uninstall) and [upgrade](https://nix.dev/manual/nix/stable/command-ref/nix-env/upgrade) packages.

## Querying the store

So far we learned how to query and manipulate the environment. But all of the environment components point to the store.

To query and manipulate the store, there's the `nix-store` command. We can do some interesting things, but we'll only see some queries for now.

To show the direct runtime dependencies of `hello`:

```console
$ nix-store -q --references `which hello`
/nix/store/fg4yq8i8wd08xg3fy58l6q73cjy8hjr2-glibc-2.27
/nix/store/58r35bqb4f3lxbnbabq718svq9i2pda3-hello-2.10
```

The argument to `nix-store` can be anything as long as it points to the Nix store. It will follow symlinks.

It may not make sense to you right now, but let's print reverse dependencies of `hello`:

```console
$ nix-store -q --referrers `which hello`
/nix/store/58r35bqb4f3lxbnbabq718svq9i2pda3-hello-2.10
/nix/store/fhvy2550cpmjgcjcx5rzz328i0kfv3z3-env-manifest.nix
/nix/store/yzdk0xvr0b8dcwhi2nns6d75k2ha5208-env-manifest.nix
/nix/store/mp987abm20c70pl8p31ljw1r5by4xwfw-user-environment
/nix/store/ppr3qbq7fk2m2pa49i2z3i32cvfhsv7p-user-environment
```

Was it what you expected? It turns out that our environments depend upon `hello`. Yes, that means that the environments are in the store, and since they contain symlinks to `hello`, therefore the environment depends upon `hello`.

Two environments were listed, generation 2 and generation 3, since these are the ones that had `hello` installed in them.

The `manifest.nix` file contains metadata about the environment, such as which derivations are installed. So that `nix-env` can list, upgrade or remove them. And yet again, the current `manifest.nix` can be found at `~/.nix-profile/manifest.nix`.

## Closures

The closures of a derivation is a list of all its dependencies, recursively, including absolutely everything necessary to use that derivation.

```console
$ nix-store -qR `which man`
[...]
```

Copying all those derivations to the Nix store of another machine makes you able to run `man` out of the box on that other machine. That's the base of deployment using Nix, and you can already foresee the potential when deploying software in the cloud (hint: `nix-copy-closures` and `nix-store --export`).

A nicer view of the closure:

```console
$ nix-store -q --tree `which man`
[...]
```

With the above command, you can find out exactly why a _runtime_ dependency, be it direct or indirect, exists for a given derivation.

The same applies to environments. As an exercise, run `nix-store -q --tree ~/.nix-profile`, and see that the first children are direct dependencies of the user environment: the installed derivations, and the `manifest.nix`.

## Dependency resolution

There isn't anything like `apt` which solves a SAT problem in order to satisfy dependencies with lower and upper bounds on versions. There's no need for this because all the dependencies are static: if a derivation X depends on a derivation Y, then it always depends on it. A version of X which depended on Z would be a different derivation.

## Recovering the hard way

```console
$ nix-env -e '*'
uninstalling 'hello-2.10'
uninstalling 'nix-2.1.3'
[...]
```

Oops, that uninstalled all derivations from the environment, including Nix. That means we can't even run `nix-env`, what now?

Previously we got `nix-env` from the environment. Environments are a convenience for the user, but Nix is still there in the store!

First, pick one `nix-2.1.3` derivation: `ls /nix/store/*nix-2.1.3`, say `/nix/store/ig31y9gfpp8pf3szdd7d4sf29zr7igbr-nix-2.1.3`.

The first option is to rollback:

```console
$ /nix/store/ig31y9gfpp8pf3szdd7d4sf29zr7igbr-nix-2.1.3/bin/nix-env --rollback
```

The second option is to install Nix, thus creating a new generation:

```console
$ /nix/store/ig31y9gfpp8pf3szdd7d4sf29zr7igbr-nix-2.1.3/bin/nix-env -i /nix/store/ig31y9gfpp8pf3szdd7d4sf29zr7igbr-nix-2.1.3/bin/nix-env
```

## Channels

So where are we getting packages from? We said something about this already in the [second article](02-install-on-your-running-system.md). There's a list of channels from which we get packages, although usually we use a single channel. The tool to manage channels is [nix-channel](https://nix.dev/manual/nix/stable/command-ref/nix-channel).

```console
$ nix-channel --list
nixpkgs http://nixos.org/channels/nixpkgs-unstable
```

If you're using NixOS, you may not see any output from the above command (if you're using the default), or you may see a channel whose name begins with "nixos-" instead of "nixpkgs".

That's essentially the contents of `~/.nix-channels`.

<div class="info">

Note: `~/.nix-channels` is not a symlink to the nix store!

</div>

To update the channel run `nix-channel --update`. That will download the new Nix expressions (descriptions of the packages), create a new generation of the channels profile and unpack it under `~/.nix-defexpr/channels`.

This is quite similar to `apt-get update`. (See [this table](https://wiki.nixos.org/wiki/Cheatsheet) for a rough mapping between Ubuntu and NixOS package management.)

## Conclusion

We learned how to query the user environment and to manipulate it by installing and uninstalling software. Upgrading software is also straightforward, as you can read in [the manual](https://nix.dev/manual/nix/stable/command-ref/nix-env/upgrade) (`nix-env -u` will upgrade all packages in the environment).

Every time we change the environment, a new generation is created. Switching between generations is easy and immediate.

Then we learned how to query the store. We inspected the dependencies and reverse dependencies of store paths.

We saw how symlinks are used to compose paths from the Nix store, a useful trick.

A quick analogy with programming languages: you have the heap with all the objects, that corresponds to the Nix store. You have objects that point to other objects, those correspond to derivations. This is a suggestive metaphor, but will it be the right path?

## Next pill

...we will learn the basics of the Nix language. The Nix language is used to describe how to build derivations, and it's the basis for everything else, including NixOS. Therefore it's very important to understand both the syntax and the semantics of the language.
