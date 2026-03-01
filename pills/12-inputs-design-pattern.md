# Package Repositories and the Inputs Design Pattern {#inputs-design-pattern}

Welcome to the 12th Nix pill. In the previous [11th pill](11-garbage-collector.md), we stopped packaging and cleaned up the system with the garbage collector.

This time, we will resume packaging and improve different aspects of it. We will also demonstrate how to create a repository of multiple packages.

## Repositories in Nix

Package repositories in Nix arose naturally from the need to organize packages. There is no preset directory structure or packaging policy prescribed by Nix itself; Nix, as a full, functional programming language, is powerful enough to support multiple different repository formats.

Over time, the `nixpkgs` repository evolved a particular structure. This structure reflects the history of Nix as well as the design patterns adopted by its users as useful tools in building and organizing packages. Below, we will examine some of these patterns in detail.

## The single repository pattern

Different operating system distributions have different opinions about how package repositories should be organized. Systems like Debian scatter packages in several small repositories (which tends to make tracking interdependent changes more difficult, and hinders contributions to the repositories), while systems like Gentoo put all package descriptions in a single repository.

Nix follows the "single repository" pattern by placing all descriptions of all packages into [nixpkgs](https://github.com/NixOS/nixpkgs). This approach has proven natural and attractive for new contributions.

For the rest of this pill, we will adopt the single repository pattern. The natural implementation in Nix is to create a top-level Nix expression, followed by one expression for each package. The top-level expression imports and combines all package expressions in an attribute set mapping names to packages.

In some programming languages, such an approach \-- including every possible package description in a single data structure \-- would be untenable due to the language needing to load the entire data structure into memory before operating on it. Nix, however, is a lazy language and only evaluates what is needed.

## Packaging `graphviz`

We have already packaged GNU `hello`. Next, we will package a graph-drawing program called `graphviz` so that we can create a repository containing multiple packages. The `graphviz` package was selected because it uses the standard autotools build system and requires no patching. It also has optional dependencies, which will give us an opportunity to illustrate a technique to configure builds to a particular situation.

First, we download `graphviz` from [gitlab](https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/2.49.3/graphviz-2.49.3.tar.gz). The `graphviz.nix` expression is straightforward:

```nix
let
  pkgs = import <nixpkgs> { };
  mkDerivation = import ./autotools.nix pkgs;
in
mkDerivation {
  name = "graphviz";
  src = ./graphviz-2.49.3.tar.gz;
}
```

If we build the project with `nix-build graphviz.nix`, we will get runnable binaries under `result/bin`. Notice how we reused the same `autotools.nix` of `hello.nix.`

By default, `graphviz` does not compile with the ability to produce `png` files. Thus, the derivation above will build a binary supporting only the native output formats, as we see below:

```console
$ echo 'graph test { a -- b }'|result/bin/dot -Tpng -o test.png
Format: "png" not recognized. Use one of: canon cmap [...]
```

If we want to produce a `png` file with `graphviz`, we must add it to our derivation. The place to do so is in `autotools.nix`, where we created a `buildInputs` variable that gets concatenated to `baseInputs`. This is the exact reason for this variable: to allow users of `autotools.nix` to add additional inputs from package expressions.

Version 2.49 of `graphviz` has several plugins to output `png`. For simplicity, we will use `libgd`.

## Passing library information to `pkg-config` via environment variables

The `graphviz` configuration script uses `pkg-config` to specify which flags are passed to the compiler. Since there is no global location for libraries, we need to tell `pkg-config` where to find its description files, which tell the configuration script where to find headers and libraries.

In classic POSIX systems, `pkg-config` just finds the `.pc` files of all installed libraries in system folders like `/usr/lib/pkgconfig`. However, these files are not present in the isolated environments presented to Nix.

As an alternative, we can inform `pkg-config` about the location of libraries via the `PKG_CONFIG_PATH` environment variable. We can populate this environment variable using the same trick we used for `PATH`: automatically filling the variables from `buildInputs`. This is the relevant snippet of `setup.sh`:

```sh
for p in $baseInputs $buildInputs; do
    if [ -d $p/bin ]; then
        export PATH="$p/bin${PATH:+:}$PATH"
    fi
    if [ -d $p/lib/pkgconfig ]; then
        export PKG_CONFIG_PATH="$p/lib/pkgconfig${PKG_CONFIG_PATH:+:}$PKG_CONFIG_PATH"
    fi
done
```

Now if we add derivations to `buildInputs`, their `lib/pkgconfig` and `bin` paths are automatically added in `setup.sh`.

## Completing graphviz with `gd`

Below, we finish the expression for `graphviz` with `gd` support. Note the use of the `with` expression in `buildInputs` to avoid repeating `pkgs`:

```nix
let
  pkgs = import <nixpkgs> { };
  mkDerivation = import ./autotools.nix pkgs;
in
mkDerivation {
  name = "graphviz";
  src = ./graphviz-2.49.3.tar.gz;
  buildInputs = with pkgs; [
    pkg-config
    (pkgs.lib.getLib gd)
    (pkgs.lib.getDev gd)
  ];
}
```

We add `pkg-config` to the derivation to make this tool available for the configure script. As `gd` is a package with [split outputs](https://nixos.org/manual/nixpkgs/stable/#sec-multiple-outputs-), we need to add both the library and development outputs.

After building, `graphviz` can now create `png`s.

## The repository expression

Now that we have two packages, we want to combine them into a single repository. To do so, we'll mimic what `nixpkgs` does: we will create a single attribute set containing derivations. This attribute set can then be imported, and derivations can be selected by accessing the top-level attribute set.

Using this technique we are able to abstract from the file names. Instead of referring to a package by `REPO/some/sub/dir/package.nix`, this technique allows us to select a derivation as `importedRepo.package` (or `pkgs.package` in our examples).

To begin, create a default.nix in the current directory:

```nix
{
  hello = import ./hello.nix;
  graphviz = import ./graphviz.nix;
}
```

This file is ready to use with `nix repl`:

```console
$ nix repl
nix-repl> :l default.nix
Added 2 variables.
nix-repl> hello
«derivation /nix/store/dkib02g54fpdqgpskswgp6m7bd7mgx89-hello.drv»
nix-repl> graphviz
«derivation /nix/store/zqv520v9mk13is0w980c91z7q1vkhhil-graphviz.drv»
```

With `nix-build`, we can pass the -A option to access an attribute of the set from the given `.nix` expression:

```console
$ nix-build default.nix -A hello
[...]
$ result/bin/hello
Hello, world!
```

The `default.nix` file is special. When a directory contains a `default.nix` file, it is used as the implicit nix expression of the directory. This, for example, allows us to run `nix-build -A hello` without specifying `default.nix` explicitly.

We can now use `nix-env` to install the package into our user environment:

```console
$ nix-env -f . -iA graphviz
[...]
$ dot -V
```

Taking a closer look at the above command, we see the following options:

- The -f option is used to specify the expression to use. In this case, the expression is the `./default.nix` of the current directory.

- The -i option stands for "installation".

- The -A is the same as above for `nix-build`.

We reproduced the very basic behavior of `nixpkgs`: combining multiple derivations into a single, top-level attribute set.

## The inputs pattern

The approach we've taken so far has a few problems:

- First, `hello.nix` and `graphviz.nix` are dependent on `nixpkgs`, which they import directly. A better approach would be to pass in `nixpkgs` as an argument, as we did in `autotools.nix`.

- Second, we don't have a straightforward way to compile different variants of the same software, such as `graphviz` with or without `libgd` support.

- Third, we don't have a way to test `graphviz` with a particular `libgd` version.

Until now, our approach to addressing the above problems has been inadequate and required changing the nix expression to match our needs. With the `inputs` pattern, we provide another answer: let the user change the `inputs` of the expression.

When we talk about "the inputs of an expression", we are referring to the set of derivations needed to build that expression. In this case:

- `mkDerivation` from `autotools`. Recall that `mkDerivation` has an implicit dependency on the toolchain.

- `libgd` and its dependencies.

The `./src` directory is also an input, but we wouldn't change the source from the caller. In `nixpkgs` we prefer to write another expression for version bumps (e.g. because patches or different inputs are needed).

Our goal is to make package expressions independent of the repository. To achieve this, we use functions to declare inputs for a derivation. For example, with `graphviz.nix`, we make the following changes to make the derivation independent of the repository and customizable:

```nix
{ mkDerivation, lib, gdSupport ? true, gd, pkg-config }:

mkDerivation {
  name = "graphviz";
  src = ./graphviz-2.49.3.tar.gz;
  buildInputs =
    if gdSupport
      then [
        pkg-config
        (lib.getLib gd)
        (lib.getDev gd)
      ]
      else [];
}
```

Recall that "`{...}: ...`" is the syntax for defining functions accepting an attribute set as argument; the above snippet just defines a function.

We made `gd` and its dependencies optional. If `gdSupport` is true (which it is by default), we will fill `buildInputs` and `graphviz` will be built with `gd` support. Otherwise, if an attribute set is passed with `gdSupport = false;`, the build will be completed without `gd` support.

Going back to `default.nix`, we modify our expression to utilize the inputs pattern:

```nix
let
  pkgs = import <nixpkgs> { };
  mkDerivation = import ./autotools.nix pkgs;
in
with pkgs;
{
  hello = import ./hello.nix { inherit mkDerivation; };
  graphviz = import ./graphviz.nix {
    inherit
      mkDerivation
      lib
      gd
      pkg-config
      ;
  };
  graphvizCore = import ./graphviz.nix {
    inherit
      mkDerivation
      lib
      gd
      pkg-config
      ;
    gdSupport = false;
  };
}
```

We factorized the import of `nixpkgs` and `mkDerivation`, and also added a variant of `graphviz` with `gd` support disabled. The result is that both `hello.nix` (left as an exercise for the reader) and `graphviz.nix` are independent of the repository and customizable by passing specific inputs.

If we wanted to build `graphviz` with a specific version of `gd`, it would suffice to pass `gd = ...;`.

If we wanted to change the toolchain, we would simply pass a different `mkDerivation` function.

Let's take a closer look at the snippet and dissect the syntax:

- The entire expression in `default.nix` returns an attribute set with the keys `hello`, `graphviz`, and `graphvizCore`.

- With "`let`", we define some local variables.

- We bring `pkgs` into the scope when defining the package set. This saves us from having to type `pkgs`" repeatedly.

- We import `hello.nix` and `graphviz.nix`, which each return a function. We call the functions with a set of inputs to get back the derivation.

- The "`inherit x`" syntax is equivalent to "`x = x`". This means that the "`inherit gd`" here, combined with the above "`with pkgs;`", is equivalent to "`gd = pkgs.gd`".

The entire repository of this can be found at the [pill 12](https://gist.github.com/tfc/ca800a444b029e85a14e530c25f8e872) gist.

## Conclusion

The "`inputs`" pattern allows our expressions to be easily customizable through a set of arguments. These arguments could be flags, derivations, or any other customizations enabled by the nix language. Our package expressions are simply functions: there is no extra magic present.

The "`inputs`" pattern also makes the expressions independent of the repository. Given that we pass all needed information through arguments, it is possible to use these expressions in any other context.

## Next pill

In the next pill, we will talk about the "`callPackage`" design pattern. This removes the tedium of specifying the names of the inputs twice: once in the top-level `default.nix`, and once in the package expression. With `callPackage`, we will implicitly pass the necessary inputs from the top-level expression.
