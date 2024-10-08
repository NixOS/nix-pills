# Install on Your Running System

Welcome to the second Nix pill. In the [first](01-why-you-should-give-it-a-try.md) pill we briefly described Nix.

Now we'll install Nix on our running system and understand what changed in our system after the installation. **If you're using NixOS, Nix is already installed; you can skip to the [next](03-enter-environment.md) pill.**

For installation instructions, please refer to the Nix Reference Manual on [Installing Nix](https://nix.dev/manual/nix/stable/installation/installing-binary).

## Installation

These articles are not a tutorial on _using_ Nix. Instead, we're going to walk through the Nix system to understand the fundamentals.

The first thing to note: derivations in the Nix store refer to other derivations which are themselves in the Nix store. They don't use `libc` from our system or anywhere else. It's a self-contained store of all the software we need to bootstrap up to any particular package.

<div class="info">

Note: In a multi-user installation, such as the one used in NixOS, the store is owned by root and multiple users can install and build software through a Nix daemon. You can read more about [multi-user installations here](https://nix.dev/manual/nix/stable/installation/installing-binary#multi-user-installation).

</div>

## The beginnings of the Nix store

Start looking at the output of the install command:

```
copying Nix to /nix/store..........................
```

That's the `/nix/store` we were talking about in the first article. We're copying in the necessary software to bootstrap a Nix system. You can see bash, coreutils, the C compiler toolchain, perl libraries, sqlite and Nix itself with its own tools and libnix.

You may have noticed that `/nix/store` can contain not only directories, but also files, still always in the form «hash-name».

## The Nix database

Right after copying the store, the installation process initializes a database:

```
initialising Nix database...
```

Yes, Nix also has a database. It's stored under `/nix/var/nix/db`. It is a sqlite database that keeps track of the dependencies between derivations.

The schema is very simple: there's a table of valid paths, mapping from an auto increment integer to a store path.

Then there's a dependency relation from path to paths upon which they depend.

You can inspect the database by installing sqlite (`nix-env -iA sqlite -f '<nixpkgs>'`) and then running `sqlite3 /nix/var/nix/db/db.sqlite`.

<div class="info">

Note: If this is the first time you're using Nix after the initial installation, remember you must close and open your terminals first, so that your shell environment will be updated.

</div>

<div class="warning">

Important: Never change `/nix/store` manually. If you do, then it will no longer be in sync with the sqlite db, unless you _really_ know what you are doing.

</div>

## The first profile

Next in the installation, we encounter the concept of the [profile](https://nix.dev/manual/nix/stable/package-management/profiles):

<pre><code class="hljs">creating /home/nix/.nix-profile
installing 'nix-2.1.3'
building path(s) `/nix/store/a7p1w3z2h8pl00ywvw6icr3g5l9vm5r7-<b>user-environment</b>'
created 7 symlinks in user environment
</code></pre>

A profile in Nix is a general and convenient concept for realizing rollbacks. Profiles are used to compose components that are spread among multiple paths under a new unified path. Not only that, but profiles are made up of multiple "generations": they are versioned. Whenever you change a profile, a new generation is created.

Generations can be switched and rolled back atomically, which makes them convenient for managing changes to your system.

Let's take a closer look at our profile:

<pre><code class="hljs">$ ls -l ~/.nix-profile/
bin -> /nix/store/ig31y9gfpp8pf3szdd7d4sf29zr7igbr-<b>nix-2.1.3</b>/bin
[...]
manifest.nix -> /nix/store/q8b5238akq07lj9gfb3qb5ycq4dxxiwm-<b>env-manifest.nix</b>
[...]
share -> /nix/store/ig31y9gfpp8pf3szdd7d4sf29zr7igbr-<b>nix-2.1.3</b>/share
</code></pre>

That `nix-2.1.3` derivation in the Nix store is Nix itself, with binaries and libraries. The process of "installing" the derivation in the profile basically reproduces the hierarchy of the `nix-2.1.3` store derivation in the profile by means of symbolic links.

The contents of this profile are special, because only one program has been installed in our profile, therefore e.g. the `bin` directory points to the only program which has been installed (Nix itself).

But that's only the contents of the latest generation of our profile. In fact, `~/.nix-profile` itself is a symbolic link to `/nix/var/nix/profiles/default`.

In turn, that's a symlink to `default-1-link` in the same directory. Yes, that means it's the first generation of the `default` profile.

Finally, `default-1-link` is a symlink to the nix store "user-environment" derivation that you saw printed during the installation process.

We'll talk about `manifest.nix` more in the next article.

## Nixpkgs expressions

More output from the installer:

```
downloading Nix expressions from `http://releases.nixos.org/nixpkgs/nixpkgs-14.10pre46060.a1a2851/nixexprs.tar.xz'...
unpacking channels...
created 2 symlinks in user environment
modifying /home/nix/.profile...
```

Nix expressions are written in the [Nix language](https://nix.dev/tutorials/nix-language) and used to describe packages and how to build them. [Nixpkgs](https://nixos.org/nixpkgs/) is the repository containing all of the expressions: <https://github.com/NixOS/nixpkgs>.

The installer downloaded the package descriptions from commit `a1a2851`.

The second profile we discover is the channels profile. `~/.nix-defexpr/channels` points to `/nix/var/nix/profiles/per-user/nix/channels` which points to `channels-1-link` which points to a Nix store directory containing the downloaded Nix expressions.

Channels are a set of packages and expressions available for download. Similar to Debian stable and unstable, there's a stable and unstable channel. In this installation, we're tracking `nixpkgs-unstable`.

Don't worry about Nix expressions yet, we'll get to them later.

Finally, for your convenience, the installer modified `~/.profile` to automatically enter the Nix environment. What `~/.nix-profile/etc/profile.d/nix.sh` really does is simply to add `~/.nix-profile/bin` to `PATH` and `~/.nix-defexpr/channels/nixpkgs` to `NIX_PATH`. We'll discuss `NIX_PATH` later.

Read `nix.sh`, it's short.

## FAQ: Can I change /nix to something else?

You can, but there's a good reason to keep using `/nix` instead of a different directory. All the derivations depend on other derivations by using absolute paths. We saw in the first article that bash referenced a `glibc` under a specific absolute path in `/nix/store`.

You can see for yourself, don't worry if you see multiple bash derivations:

```console
$ ldd /nix/store/*bash*/bin/bash
[...]
```

Keeping the store in `/nix` means we can grab the binary cache from nixos.org (just like you grab packages from debian mirrors) otherwise:

- `glibc` would be installed under `/foo/store`

- Thus bash would need to point to `glibc` under `/foo/store`, instead of under `/nix/store`

- So the binary cache can't help, because we need a _different_ bash, and so we'd have to recompile everything ourselves.

After all `/nix` is a sensible place for the store.

## Conclusion

We've installed Nix on our system, fully isolated and owned by the `nix` user as we're still coming to terms with this new system.

We learned some new concepts like profiles and channels. In particular, with profiles we're able to manage multiple generations of a composition of packages, while with channels we're able to download binaries from `nixos.org`.

The installation put everything under `/nix`, and some symlinks in the Nix user home. That's because every user is able to install and use software in her own environment.

I hope I left nothing uncovered so that you think there's some kind of magic going on behind the scenes. It's all about putting components in the store and symlinking these components together.

## Next pill...

...we will enter the Nix environment and learn how to interact with the store.
