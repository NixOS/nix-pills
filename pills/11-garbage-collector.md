# The Garbage Collector {#garbage-collector}

Welcome to the 11th Nix pill. In the previous [10th pill](10-developing-with-nix-shell.md), we drew a parallel between the isolated build environment provided by `nix-build` and the isolated development shell provided by `nix-shell`. Using `nix-shell` allowed us to debug, modify, and manually build software using an environment that is almost identical to the one provided by `nix-build`.

Today, we will stop focusing on packaging and instead look at a critical component of Nix: the garbage collector. When we use Nix tools, we are often building derivations. This includes `.drv` files as well as out paths. These artifacts go in the Nix store and take up space in our storage. Eventually we may wish to free up some space by removing derivations we no longer need. This is the focus of the 11th pill. By default, Nix takes a relatively conservative approach when automatically deciding which derivations are "needed". In this pill, we will also see a technique to conduct more destructive upgrade and deletion operations.

## How does garbage collection work?

Programming languages with garbage collectors use the concept of a set of "garbage collector (or 'GC') roots" to keep track of "live" objects. A GC root is an object that is always considered "live" (unless explicitly removed as GC root). The garbage collection process starts from the GC roots and proceeds by recursively marking object references as "live". All other objects can be collected and deleted.

Instead of objects, Nix's garbage collection operates on store paths, [with the GC roots themselves being store paths](https://nix.dev/manual/nix/stable/package-management/garbage-collector-roots). . This approach is much more principled than traditional package managers such as `dpkg` or `rpm`, which may leave around unused packages or dangling files.

The implementation is very simple and transparent to the user. The primary GC roots are stored under `/nix/var/nix/gcroots`. If there is a symlink to a store path, then the linked store path is a GC root.

Nix allows this directory to have subdirectories: it will simply recursively traverse the subdirectories in search of symlinks to store paths. When a symlink is encountered, its target is added to the list of live store paths.

In summary, Nix maintains a list of GC roots. These roots can then be used to compute a list of all live store paths. Any other store paths are considered dead. Deleting these paths is now straightforward. Nix first moves dead store paths to `/nix/store/trash`, which is an atomic operation. Afterwards, the trash is emptied.

## Playing with the GC

Before we begin we first run the [nix garbage collector](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage) so that we have a clean setup for our experiments:

```console
$ nix-collect-garbage
finding garbage collector roots...
[...]
deleting unused links...
note: currently hard linking saves -0.00 MiB
1169 store paths deleted, 228.43 MiB freed
```

If we run the garbage collector again it won't find anything new to delete, as we expect. After running the garbage collector, the nix store only contains paths with references from the GC roots.

We now install a new program, `bsd-games`, inspect its store path, and examine its GC root. The `nix-store -q --roots` command is used to query the GC roots that refer to a given derivation. In this case, our current user environment refers to `bsd-games`:

```console
$ nix-env -iA nixpkgs.bsdgames
$ readlink -f `which fortune`
/nix/store/b3lxx3d3ggxcggvjw5n0m1ya1gcrmbyn-bsd-games-2.17/bin/fortune
$ nix-store -q --roots `which fortune`
/nix/var/nix/profiles/default-9-link
$ nix-env --list-generations
[...]
   9   2014-08-20 12:44:14   (current)
```

Now we remove it and run the garbage collector, and note that `bsd-games` is still in the nix store:

```console
$ nix-env -e bsd-games
uninstalling `bsd-games-2.17'
$ nix-collect-garbage
[...]
$ ls /nix/store/b3lxx3d3ggxcggvjw5n0m1ya1gcrmbyn-bsd-games-2.17
bin  share
```

The old generation is still in the nix store because it is a GC root. As we will see below, all profiles and their generations are automatically GC roots.

Removing a GC root is simple. In our case, we delete the generation that refers to `bsd-games`, run the garbage collector, and note that `bsd-games` is no longer in the nix store:

```console
$ rm /nix/var/nix/profiles/default-9-link
$ nix-env --list-generations
[...]
   8   2014-07-28 10:23:24
  10   2014-08-20 12:47:16   (current)
$ nix-collect-garbage
[...]
$ ls /nix/store/b3lxx3d3ggxcggvjw5n0m1ya1gcrmbyn-bsd-games-2.17
ls: cannot access /nix/store/b3lxx3d3ggxcggvjw5n0m1ya1gcrmbyn-bsd-games-2.17: No such file or directory
```

Note: `nix-env --list-generations` does not rely on any particular metadata. It is able to list generations based solely on the file names under the profiles directory.

Note that we removed the link from `/nix/var/nix/profiles`, not from `/nix/var/nix/gcroots`. In addition to the latter, Nix treats `/nix/var/nix/profiles` as a GC root. This is useful because it means that any profile and its generations are GC roots. Other paths are considered GC roots as well; for example, `/run/booted-system` on NixOS. The command `nix-store --gc --print-roots` prints all paths considered as GC roots when running the garbage collector.

## Indirect roots

Recall that building the GNU `hello` package with `nix-build` produces a `result` symlink in the current directory. Despite the garbage collection done above, the `hello` program is still working. Therefore, it has not been garbage collected. Since there is no other derivation that depends upon the GNU `hello` package, it must be a GC root.

In fact, `nix-build` automatically adds the `result` symlink as a GC root. Note that this is not the built derivation, but the symlink itself. These GC roots are added under `/nix/var/nix/gcroots/auto`.

```console
$ ls -l /nix/var/nix/gcroots/auto/
total 8
drwxr-xr-x 2 nix nix 4096 Aug 20 10:24 ./
drwxr-xr-x 3 nix nix 4096 Jul 24 10:38 ../
lrwxrwxrwx 1 nix nix   16 Jul 31 10:51 xlgz5x2ppa0m72z5qfc78b8wlciwvgiz -> /home/nix/result/
```

The name of the GC root symlink is not important to us at this time. What is important is that such a symlink exists and points to `/home/nix/result`. This is called an **indirect GC root**. A GC root is considered indirect if its specification is outside of `/nix/var/nix/gcroots`. In this case, this means that the target of the `result` symlink will not be garbage collected.

To remove a derivation considered "live" by an indirect GC root, there are two possibilities:

- Remove the indirect GC root from `/nix/var/nix/gcroots/auto`.

- Remove the `result` symlink.

In the first case, the derivation will be deleted from the nix store during garbage collection, and `result` becomes a dangling symlink. In the second case, the derivation is removed as well as the indirect root in `/nix/var/nix/gcroots/auto`.

Running `nix-collect-garbage` after deleting the GC root or the indirect GC root will remove the derivation from the store.

## Cleanup everything

The main source of software duplication in the nix store comes from GC roots, due to `nix-build` and profile generations. Running `nix-build` results in a GC root for the build that refers to a specific version of specific libraries, such as `glibc`. After an upgrade, we must delete the previous build if we want the garbage collector to remove the corresponding derivation, as well as if we want old dependencies cleaned up.

The same holds for profiles. Manipulating the `nix-env` profile will create further generations. Old generations refer to old software, thus increasing duplication in the nix store after an upgrade.

Other systems typically "forget" everything about their previous state after an upgrade. With Nix, we can perform this type of upgrade (having Nix remove all old derivations, including old generations), but we do so manually. There are four steps to doing this:

- First, we download a new version of the nixpkgs channel, which holds the description of all the software. This is done via `nix-channel --update`.

- Then we upgrade our installed packages with `nix-env -u`. This will bring us into a new generation with updated software.

- Then we remove all the indirect roots generated by `nix-build`: beware, as this will result in dangling symlinks. A smarter strategy would also remove the target of those symlinks.

- Finally, the `-d` option of `nix-collect-garbage` is used to delete old generations of all profiles, then collect garbage. After this, you lose the ability to rollback to any previous generation. It is important to ensure the new generation is working well before running this command.

The four steps are shown below:

```console
$ nix-channel --update
$ nix-env -u --always
$ rm /nix/var/nix/gcroots/auto/*
$ nix-collect-garbage -d
```

## Conclusion

Garbage collection in Nix is a powerful mechanism to clean up your system. The `nix-store` commands allow us to know why a certain derivation is present in the nix store, and whether or not it is eligible for garbage collection. We also saw how to conduct more destructive deletion and upgrade operations.

## Next pill

In the next pill, we will package another project and introduce the "inputs" design pattern. We've only played with a single derivation until now; however we'd like to start organizing a small repository of software. The "inputs" pattern is widely used in nixpkgs; it allows us to decouple derivations from the repository itself and increase customization opportunities.
