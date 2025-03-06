# Automatic Runtime Dependencies

Welcome to the 9th Nix pill. In the previous [8th pill](08-generic-builders.md) we wrote a generic builder for autotools projects. We fed in build dependencies and a source tarball, and we received a Nix derivation as a result.

Today we stop by the GNU `hello` program to analyze build and runtime dependencies, and we enhance our builder to eliminate unnecessary runtime dependencies.

## Build dependencies

Let's start analyzing build dependencies for our GNU `hello` package:

```console
$ nix-instantiate hello.nix
/nix/store/z77vn965a59irqnrrjvbspiyl2rph0jp-hello.drv
$ nix-store -q --references /nix/store/z77vn965a59irqnrrjvbspiyl2rph0jp-hello.drv
/nix/store/0q6pfasdma4as22kyaknk4kwx4h58480-hello-2.10.tar.gz
/nix/store/1zcs1y4n27lqs0gw4v038i303pb89rw6-coreutils-8.21.drv
/nix/store/2h4b30hlfw4fhqx10wwi71mpim4wr877-gnused-4.2.2.drv
/nix/store/39bgdjissw9gyi4y5j9wanf4dbjpbl07-gnutar-1.27.1.drv
/nix/store/7qa70nay0if4x291rsjr7h9lfl6pl7b1-builder.sh
/nix/store/g6a0shr58qvx2vi6815acgp9lnfh9yy8-gnugrep-2.14.drv
/nix/store/jdggv3q1sb15140qdx0apvyrps41m4lr-bash-4.2-p45.drv
/nix/store/pglhiyp1zdbmax4cglkpz98nspfgbnwr-gnumake-3.82.drv
/nix/store/q9l257jn9lndbi3r9ksnvf4dr8cwxzk7-gawk-4.1.0.drv
/nix/store/rgyrqxz1ilv90r01zxl0sq5nq0cq7v3v-binutils-2.23.1.drv
/nix/store/qzxhby795niy6wlagfpbja27dgsz43xk-gcc-wrapper-4.8.3.drv
/nix/store/sk590g7fv53m3zp0ycnxsc41snc2kdhp-gzip-1.6.drv
```

It has precisely the derivations referenced in the `derivation` function; nothing more, nothing less. Of course, we may not use some of them at all. However, given that our generic `mkDerivation` function always pulls such dependencies (think of it like [build-essential](https://packages.debian.org/unstable/build-essential) from Debian), we will already have these packages in the nix store for any future packages that need them.

Why are we looking at `.drv` files? Because the `hello.drv` file is the representation of the build action that builds the `hello` out path. As such, it contains the input derivations needed before building `hello`.

## Digression about NAR files

The `NAR` format is the "Nix ARchive". This format was designed due to existing archive formats, such as `tar`, being insufficient. Nix benefits from deterministic build tools, but commonly used archivers lack this property: they add padding, they do not sort files, they add timestamps, and so on. This can result in directories containing bit-identical files turning into non-bit-identical archives, which leads to different hashes.

Thus the `NAR` format was developed as a simple, deterministic archive format. `NAR`s are used extensively within Nix, as we will see below.

For more rationale and implementation details behind `NAR` see [Dolstra's PhD Thesis](http://nixos.org/~eelco/pubs/phd-thesis.pdf).

To create NAR archives from store paths, we can use `nix-store --dump` and `nix-store --restore`.

## Runtime dependencies

We now note that Nix automatically recognized build dependencies once our `derivation` call referred to them, but we never specified the runtime dependencies.

Nix handles runtime dependencies for us automatically. The technique it uses to do so may seem fragile at first glance, but it works so well that the NixOS operating system is built off of it. The underlying mechanism relies on the hash of the store paths. It proceeds in three steps:

1.  Dump the derivation as a NAR. Recall that this is a serialization of the derivation output \-- meaning this works fine whether the output is a single file or a directory.

2.  For each build dependency `.drv` and its relative out path, search the contents of the NAR for this out path.

3.  If the path is found, then it's a runtime dependency.

The snippet below shows the dependencies for `hello`.

```console
$ nix-instantiate hello.nix
/nix/store/z77vn965a59irqnrrjvbspiyl2rph0jp-hello.drv
$ nix-store -r /nix/store/z77vn965a59irqnrrjvbspiyl2rph0jp-hello.drv
/nix/store/a42k52zwv6idmf50r9lps1nzwq9khvpf-hello
$ nix-store -q --references /nix/store/a42k52zwv6idmf50r9lps1nzwq9khvpf-hello
/nix/store/94n64qy99ja0vgbkf675nyk39g9b978n-glibc-2.19
/nix/store/8jm0wksask7cpf85miyakihyfch1y21q-gcc-4.8.3
/nix/store/a42k52zwv6idmf50r9lps1nzwq9khvpf-hello
```

We see that `glibc` and `gcc` are runtime dependencies. Intuitively, `gcc` shouldn't be in this list! Displaying the printable strings in the `hello` binary shows that the out path of `gcc` does indeed appear:

```console
$ strings result/bin/hello|grep gcc
/nix/store/94n64qy99ja0vgbkf675nyk39g9b978n-glibc-2.19/lib:/nix/store/8jm0wksask7cpf85miyakihyfch1y21q-gcc-4.8.3/lib64
```

This is why Nix added `gcc`. But why is that path present in the first place? The answer is that it is the [ld rpath](http://en.wikipedia.org/wiki/Rpath): the list of directories where libraries can be found at runtime. In other distributions, this is usually not abused. But in Nix, we have to refer to particular versions of libraries, and thus the rpath has an important role.

The build process adds the `gcc` lib path thinking it may be useful at runtime, but this isn't necessary. To address issues like these, Nix provides a tool called [patchelf](https://nixos.org/patchelf.html), which reduces the rpath to the paths that are actually used by the binary.

Even after reducing the rpath, the `hello` binary would still depend upon `gcc` because of some debugging information. This unnecessarily increases the size of our runtime dependencies. We'll explore how `strip` can help us with that in the next section.

## Another phase in the builder

We will add a new phase to our autotools builder. The builder has six phases already:

1.  The "environment setup" phase

2.  The "unpack phase": we unpack the sources in the current directory (remember, Nix changes to a temporary directory first)

3.  The "change directory" phase, where we change source root to the directory that has been unpacked

4.  The "configure" phase: `./configure`

5.  The "build" phase: `make`

6.  The "install" phase: `make install`

Now we will add a new phase after the installation phase, which we call the "fixup" phase. At the end of the `builder.sh`, we append:

```console
find $out -type f -exec patchelf --shrink-rpath '{}' \; -exec strip '{}' \; 2>/dev/null
```

That is, for each file we run `patchelf --shrink-rpath` and `strip`. Note that we used two new commands here, `find` and `patchelf`. These must be added to our derivation.

**Exercise:** Add `findutils` and `patchelf` to the `baseInputs` of `autotools.nix`.

Now, we rebuild `hello.nix`...

```console
$ nix-build hello.nix
[...]
$ nix-store -q --references result
/nix/store/94n64qy99ja0vgbkf675nyk39g9b978n-glibc-2.19
/nix/store/md4a3zv0ipqzsybhjb8ndjhhga1dj88x-hello
```

and we see that `glibc` is a runtime dependency but `gcc` is not there anymore. This is exactly what we wanted.

The package is self-contained. This means that we can copy its closure onto another machine and we will be able to run it. Remember, only a very few components under the `/nix/store` are required to [run nix](02-install-on-your-running-system.md). The `hello` binary will use the exact version of `glibc` library and interpreter referred to in the binary, rather than the system one:

```console
$ ldd result/bin/hello
 linux-vdso.so.1 (0x00007fff11294000)
 libc.so.6 => /nix/store/94n64qy99ja0vgbkf675nyk39g9b978n-glibc-2.19/lib/libc.so.6 (0x00007f7ab7362000)
 /nix/store/94n64qy99ja0vgbkf675nyk39g9b978n-glibc-2.19/lib/ld-linux-x86-64.so.2 (0x00007f7ab770f000)
```

Of course, the executable will run fine as long as everything is under the `/nix/store` path.

## Conclusion

We saw some of the tools Nix provides, along with their features. In particular, we saw how Nix is able to compute runtime dependencies automatically. This is not limited to only shared libraries, but can also reference executables, scripts, Python libraries, and so forth.

Approaching builds in this way makes packages self-contained, ensuring (apart from data and configuration) that copying the runtime closure onto another machine is sufficient to run the program. This enables us to run programs without installation using `nix-shell`, and forms the basis for [reliable deployment in the cloud](https://github.com/NixOS/nixops).

## Next pill

The next pill will introduce `nix-shell`. With `nix-build`, we've always built derivations from scratch: the source gets unpacked, configured, built, and installed. But this can take a long time for large packages. What if we want to apply some small changes and compile incrementally instead, yet still want to keep a self-contained environment similar to `nix-build`? `nix-shell` enables this.
