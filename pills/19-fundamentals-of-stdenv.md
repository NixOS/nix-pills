# Fundamentals of Stdenv

Welcome to the 19th Nix pill. In the previous [18th](18-nix-store-paths.md) pill we dived into the algorithm used by Nix to compute the store paths, and also introduced fixed-output store paths.

This time we will instead look into `nixpkgs`, in particular one of its core derivations: `stdenv`.

The `stdenv` is not treated as a special derivation by Nix, but it's very important for the `nixpkgs` repository. It serves as a base for packaging software. It is used to pull in dependencies such as the GCC toolchain, GNU make, core utilities, patch and diff utilities, and so on: basic tools needed to compile a huge pile of software currently present in `nixpkgs`.

## What is stdenv?

First of all, `stdenv` is a derivation, and it's a very simple one:

```console
$ nix-build '<nixpkgs>' -A stdenv
/nix/store/k4jklkcag4zq4xkqhkpy156mgfm34ipn-stdenv
$ ls -R result/
result/:
nix-support/  setup

result/nix-support:
propagated-user-env-packages
```

It has just two files: `/setup` and `/nix-support/propagated-user-env-packages`. Don't worry about the latter. It's empty, in fact. The important file is `/setup`.

How can this simple derivation pull in all of the toolchain and basic tools needed to compile packages? Let's look at the runtime dependencies:

```console
$ nix-store -q --references result
/nix/store/3a45nb37s0ndljp68228snsqr3qsyp96-bzip2-1.0.6
/nix/store/a457ywa1haa0sgr9g7a1pgldrg3s798d-coreutils-8.24
/nix/store/zmd4jk4db5lgxb8l93mhkvr3x92g2sx2-bash-4.3-p39
/nix/store/47sfpm2qclpqvrzijizimk4md1739b1b-gcc-wrapper-4.9.3
...
```

How can it be? The package must be referring to those other packages somehow. In fact, they are hardcoded in the `/setup` file:

```console
$ head result/setup
export SHELL=/nix/store/zmd4jk4db5lgxb8l93mhkvr3x92g2sx2-bash-4.3-p39/bin/bash
initialPath="/nix/store/a457ywa1haa0sgr9g7a1pgldrg3s798d-coreutils-8.24 ..."
defaultNativeBuildInputs="/nix/store/sgwq15xg00xnm435gjicspm048rqg9y6-patchelf-0.8 ..."
```

## The setup file

Remember our generic `builder.sh` in [Pill 8](08-generic-builders.md)? It sets up a basic `PATH`, unpacks the source and runs the usual `autotools` commands for us.

The [stdenv setup file](https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/setup.sh) is exactly that. It sets up several environment variables like `PATH` and creates some helper bash functions to build a package. I invite you to read it.

The hardcoded toolchain and utilities are used to initially fill up the environment variables so that it's more pleasant to run common commands, similar to what we did with our builder with `baseInputs` and `buildInputs`.

The build with `stdenv` works in phases. Phases are like `unpackPhase`, `configurePhase`, `buildPhase`, `checkPhase`, `installPhase`, `fixupPhase`. You can see the default list in the `genericBuild` function.

What `genericBuild` does is just run these phases. Default phases are just bash functions. You can easily read them.

Every phase has hooks to run commands before and after the phase has been executed. Phases can be overwritten, reordered, whatever, it's just bash code.

How to use this file? Like our old builder. To test it, we enter a fake empty derivation, source the `stdenv` `setup`, unpack the hello sources and build it:

```console
$ nix-shell -E 'derivation { name = "fake"; builder = "fake"; system = "x86_64-linux"; }'
nix-shell$ unset PATH
nix-shell$ source /nix/store/k4jklkcag4zq4xkqhkpy156mgfm34ipn-stdenv/setup
nix-shell$ tar -xf hello-2.10.tar.gz
nix-shell$ cd hello-2.10
nix-shell$ configurePhase
...
nix-shell$ buildPhase
...
```

_I unset `PATH` to further show that the `stdenv` is sufficiently self-contained to build autotools packages that have no other dependencies._

So we ran the `configurePhase` function and `buildPhase` function and they worked. These bash functions should be self-explanatory. You can read the code in the `setup` file.

## How the setup file is built

Until now we worked with plain bash scripts. What about the Nix side? The `nixpkgs` repository offers a useful function, like we did with our old builder. It is a wrapper around the raw derivation function which pulls in the `stdenv` for us, and runs `genericBuild`. It's [stdenv.mkDerivation](https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/make-derivation.nix).

Note how `stdenv` is a derivation but it's also an attribute set which contains some other attributes, like `mkDerivation`. Nothing fancy here, just convenience.

Let's write a `hello.nix` expression using this newly discovered `stdenv`:

```nix
with import <nixpkgs> { };
stdenv.mkDerivation {
  name = "hello";
  src = ./hello-2.10.tar.gz;
}
```

Don't be scared by the `with` expression. It pulls the `nixpkgs` repository into scope, so we can directly use `stdenv`. It looks very similar to the hello expression in [Pill 8](08-generic-builders.md).

It builds, and runs fine:

```console
$ nix-build hello.nix
...
/nix/store/6y0mzdarm5qxfafvn2zm9nr01d1j0a72-hello
$ result/bin/hello
Hello, world!
```

## The stdenv.mkDerivation builder

Let's take a look at the builder used by `mkDerivation`. You can read the code [here in nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/make-derivation.nix):

```nix
{
  # ...
  builder = attrs.realBuilder or shell;
  args =
    attrs.args or [
      "-e"
      (attrs.builder or ./default-builder.sh)
    ];
  stdenv = result;
  # ...
}
```

Also take a look at our old derivation wrapper in previous pills! The builder is bash (that shell variable), the argument to the builder (bash) is `default-builder.sh`, and then we add the environment variable `$stdenv` in the derivation which is the `stdenv` derivation.

You can open [default-builder.sh](https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/default-builder.sh) and see what it does:

```sh
source $stdenv/setup
genericBuild
```

It's what we did in [Pill 10](10-developing-with-nix-shell.md) to make the derivations `nix-shell` friendly. When entering the shell, the setup file only sets up the environment without building anything. When doing `nix-build`, it actually runs the build process.

To get a clear understanding of the environment variables, look at the .drv of the hello derivation:

```console
$ nix derivation show $(nix-instantiate hello.nix)
warning: you did not specify '--add-root'; the result might be removed by the garbage collector
{
  "/nix/store/abwj50lycl0m515yblnrvwyydlhhqvj2-hello.drv": {
    "outputs": {
      "out": {
        "path": "/nix/store/6y0mzdarm5qxfafvn2zm9nr01d1j0a72-hello"
      }
    },
    "inputSrcs": [
      "/nix/store/9krlzvny65gdc8s7kpb6lkx8cd02c25b-default-builder.sh",
      "/nix/store/svc70mmzrlgq42m9acs0prsmci7ksh6h-hello-2.10.tar.gz"
    ],
    "inputDrvs": {
      "/nix/store/hcgwbx42mcxr7ksnv0i1fg7kw6jvxshb-bash-4.4-p19.drv": [
        "out"
      ],
      "/nix/store/sfxh3ybqh97cgl4s59nrpi78kgcc8f3d-stdenv-linux.drv": [
        "out"
      ]
    },
    "platform": "x86_64-linux",
    "builder": "/nix/store/q1g0rl8zfmz7r371fp5p42p4acmv297d-bash-4.4-p19/bin/bash",
    "args": [
      "-e",
      "/nix/store/9krlzvny65gdc8s7kpb6lkx8cd02c25b-default-builder.sh"
    ],
    "env": {
      "buildInputs": "",
      "builder": "/nix/store/q1g0rl8zfmz7r371fp5p42p4acmv297d-bash-4.4-p19/bin/bash",
      "configureFlags": "",
      "depsBuildBuild": "",
      "depsBuildBuildPropagated": "",
      "depsBuildTarget": "",
      "depsBuildTargetPropagated": "",
      "depsHostBuild": "",
      "depsHostBuildPropagated": "",
      "depsTargetTarget": "",
      "depsTargetTargetPropagated": "",
      "name": "hello",
      "nativeBuildInputs": "",
      "out": "/nix/store/6y0mzdarm5qxfafvn2zm9nr01d1j0a72-hello",
      "propagatedBuildInputs": "",
      "propagatedNativeBuildInputs": "",
      "src": "/nix/store/svc70mmzrlgq42m9acs0prsmci7ksh6h-hello-2.10.tar.gz",
      "stdenv": "/nix/store/6kz2vbh98s2r1pfshidkzhiy2s2qdw0a-stdenv-linux",
      "system": "x86_64-linux"
    }
  }
}
```

It's so short I decided to paste it entirely above. The builder is bash, with `-e default-builder.sh` arguments. Then you can see the `src` and `stdenv` environment variables.

The last bit, the `unpackPhase` in the setup, is used to unpack the sources and enter the directory. Again, like we did in our old builder.

## Conclusion

The `stdenv` is the core of the `nixpkgs` repository. All packages use the `stdenv.mkDerivation` wrapper instead of the raw derivation. It does a bunch of operations for us and also sets up a pleasant build environment.

The overall process is simple:

- `nix-build`

- `bash -e default-builder.sh`

- `source $stdenv/setup`

- `genericBuild`

That's it. Everything you need to know about the stdenv phases is in the [setup file](https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/setup.sh).

Really, take your time to read that file. Don't forget that juicy docs are also available in the [nixpkgs manual](http://nixos.org/nixpkgs/manual/#chap-stdenv).

## Next pill...

...we will talk about how to add dependencies to our packages with `buildInputs` and `propagatedBuildInputs`, and influence downstream builds with setup hooks and env hooks. These concepts are crucial to how `nixpkgs` packages are composed.
