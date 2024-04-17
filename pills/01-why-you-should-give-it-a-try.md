# Why You Should Give it a Try

## Introduction

Welcome to the first post of the "[Nix](https://nixos.org/nix) in pills" series. Nix is a purely functional package manager and deployment system for POSIX.

There's a lot of documentation that describes what Nix, [NixOS](https://nixos.org/nixos) and related projects are. But the purpose of this post is to convince you to give Nix a try. Installing NixOS is not required, but sometimes I may refer to NixOS as a real world example of Nix usage for building a whole operating system.

## Rationale for this series

The [Nix](https://nixos.org/manual/nix), [Nixpkgs](https://nixos.org/manual/nixpkgs/), and [NixOS](https://nixos.org/manual/nixos/) manuals along with [the wiki](https://wiki.nixos.org/) are excellent resources for explaining how Nix/NixOS works, how you can use it, and how cool things are being done with it. However, at the beginning you may feel that some of the magic which happens behind the scenes is hard to grasp.

This series aims to complement the existing explanations from the more formal documents.

The following is a description of Nix. Just as with pills, I'll try to be as short as possible.

## Not being purely functional

Most, if not all, widely used package managers ([dpkg](https://wiki.debian.org/dpkg), [rpm](http://www.rpm.org/), ...) mutate the global state of the system. If a package `foo-1.0` installs a program to `/usr/bin/foo`, you cannot install `foo-1.1` as well, unless you change the installation paths or the binary name. But changing the binary names means breaking users of that binary.

There are some attempts to mitigate this problem. Debian, for example, partially solves the problem with the [alternatives](https://wiki.debian.org/DebianAlternatives) system.

So while in theory it's possible with some current systems to install multiple versions of the same package, in practice it's very painful.

Let's say you need an nginx service and also an nginx-openresty service. You have to create a new package that changes all the paths to have, for example, an `-openresty` suffix.

Or suppose that you want to run two different instances of mysql: 5.2 and 5.5. The same thing applies, plus you have to also make sure the two mysqlclient libraries do not collide.

This is not impossible but it _is_ very inconvenient. If you want to install two whole stacks of software like GNOME 3.10 and GNOME 3.12, you can imagine the amount of work.

From an administrator's point of view: you can use containers. The typical solution nowadays is to create a container per service, especially when different versions are needed. That somewhat solves the problem, but at a different level and with other drawbacks. For example, needing orchestration tools, setting up a shared cache of packages, and new machines to monitor rather than simple services.

From a developer's point of view: you can use virtualenv for python, or jhbuild for gnome, or whatever else. But then how do you mix the two stacks? How do you avoid recompiling the same thing when it could instead be shared? Also you need to set up your development tools to point to the different directories where libraries are installed. Not only that, there's the risk that some of the software incorrectly uses system libraries.

And so on. Nix solves all this at the packaging level and solves it well. A single tool to rule them all.

## Being purely functional

Nix makes no assumptions about the global state of the system. This has many advantages, but also some drawbacks of course. The core of a Nix system is the Nix store, usually installed under `/nix/store`, and some tools to manipulate the store. In Nix there is the notion of a _derivation_ rather than a package. The difference can be subtle at the beginning, so I will often use the words interchangeably.

Derivations/packages are stored in the Nix store as follows: `/nix/store/«hash-name»`, where the hash uniquely identifies the derivation (this isn't quite true, it's a little more complex), and the name is the name of the derivation.

Let's take a bash derivation as an example: `/nix/store/s4zia7hhqkin1di0f187b79sa2srhv6k-bash-4.2-p45/`. This is a directory in the Nix store which contains `bin/bash`.

What that means is that there's no `/bin/bash`, there's only that self-contained build output in the store. The same goes for coreutils and everything else. To make them convenient to use from the shell, Nix will arrange for binaries to appear in your `PATH` as appropriate.

What we have is basically a store of all packages (with different versions occupying different locations), and everything in the Nix store is immutable.

In fact, there's no ldconfig cache either. So where does bash find libc?

```console
$ ldd `which bash`
libc.so.6 => /nix/store/94n64qy99ja0vgbkf675nyk39g9b978n-glibc-2.19/lib/libc.so.6 (0x00007f0248cce000)
```

It turns out that when bash was built, it was built against that specific version of glibc in the Nix store, and at runtime it will require exactly that glibc version.

Don't be confused by the version in the derivation name: it's only a name for us humans. You may end up having two derivations with the same name but different hashes: it's the hash that really matters.

What does all this mean? It means that you could run mysql 5.2 with glibc-2.18, and mysql 5.5 with glibc-2.19. You could use your python module with python 2.7 compiled with gcc 4.6 and the same python module with python 3 compiled with gcc 4.8, all in the same system.

In other words: no dependency hell, not even a dependency resolution algorithm. Straight dependencies from derivations to other derivations.

From an administrator's point of view: if you want an old PHP version for one application, but want to upgrade the rest of the system, that's not painful any more.

From a developer's point of view: if you want to develop webkit with llvm 3.4 and 3.3, that's not painful any more.

## Mutable vs. immutable

When upgrading a library, most package managers replace it in-place. All new applications run afterwards with the new library without being recompiled. After all, they all refer dynamically to `libc6.so`.

Since Nix derivations are immutable, upgrading a library like glibc means recompiling all applications, because the glibc path to the Nix store has been hardcoded.

So how do we deal with security updates? In Nix we have some tricks (still pure) to solve this problem, but that's another story.

Another problem is that unless software has in mind a pure functional model, or can be adapted to it, it can be hard to compose applications at runtime.

Let's take Firefox for example. On most systems, you install flash, and it starts working in Firefox because Firefox looks in a global path for plugins.

In Nix, there's no such global path for plugins. Firefox therefore must know explicitly about the path to flash. The way we handle this problem is to wrap the Firefox binary so that we can setup the necessary environment to make it find flash in the nix store. That will produce a new Firefox derivation: be aware that it takes a few seconds, and it makes composition harder at runtime.

There are no upgrade/downgrade scripts for your data. It doesn't make sense with this approach, because there's no real derivation to be upgraded. With Nix you switch to using other software with its own stack of dependencies, but there's no formal notion of upgrade or downgrade when doing so.

If there is a data format change, then migrating to the new data format remains your own responsibility.

## Conclusion

Nix lets you compose software at build time with maximum flexibility, and with builds being as reproducible as possible. Not only that, due to its nature deploying systems in the cloud is so easy, consistent, and reliable that in the Nix world all existing self-containment and orchestration tools are deprecated by [NixOps](http://nixos.org/nixops/).

It however _currently_ falls short when working with dynamic composition at runtime or replacing low level libraries, due to the need to rebuild dependencies.

That may sound scary, however after running NixOS on both a server and a laptop desktop, I'm very satisfied so far. Some of the architectural problems just need some man-power, other design problems still need to be solved as a community.

Considering [Nixpkgs](https://nixos.org/nixpkgs/) ([github link](https://github.com/NixOS/nixpkgs)) is a completely new repository of all the existing software, with a completely fresh concept, and with few core developers but overall year-over-year increasing contributions, the current state is more than acceptable and beyond the experimental stage. In other words, it's worth your investment.

## Next pill...

...we will install Nix on top of your current system (I assume GNU/Linux, but we also have OSX users) and start inspecting the installed software.
