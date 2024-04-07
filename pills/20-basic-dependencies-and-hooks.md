# Basic Dependencies and Hooks

Welcome to the 20th Nix pill. In the previous [19th](19-fundamentals-of-stdenv.md) pill we introduced Nixpkgs' stdenv, including `setup.sh` script, `default-builder.sh` helper script, and `stdenv.mkDerivation` builder. We focused on how stdenv is put together, and how it's used, and a bit about the phases of `genericBuild`.

This time, we'll focus on the interaction of packages built with `stdenv.mkDerivation`. Packages need to depend on each other, of course. For this we have `buildInputs` and `propagatedBuildInputs` attributes. We've also found that dependencies sometimes need to influence their dependents in ways the dependents can't or shouldn't predict. For this we have setup hooks and env hooks. Together, these 4 concepts support almost all build-time package interactions.

<div class="info">

Note: The complexity of the dependencies and hooks infrastructure has increased, over time, to support cross compilation. Once you learn the core concepts, you will be able to understand the extra complexity. As a starting point, you might want to refer to nixpkgs commit [6675f0a5](https://github.com/nixos/nixpkgs/tree/6675f0a52c0962042a1000c7f20e887d0d26ae25), the last version of stdenv without cross-compilation complexity.

</div>

## The `buildInputs` Attribute

For the simplest dependencies where the current package directly needs another, we use the `buildInputs` attribute. This is exactly the pattern used in our builder in [Pill 8](08-generic-builders.html). To demo this, let's build GNU Hello, and then another package which provides a shell script that `exec`s it.

```nix
let

  nixpkgs = import <nixpkgs> { };

  inherit (nixpkgs) stdenv fetchurl which;

  actualHello = stdenv.mkDerivation {
    name = "hello-2.3";

    src = fetchurl {
      url = "mirror://gnu/hello/hello-2.3.tar.bz2";
      sha256 = "0c7vijq8y68bpr7g6dh1gny0bff8qq81vnp4ch8pjzvg56wb3js1";
    };
  };

  wrappedHello = stdenv.mkDerivation {
    name = "hello-wrapper";

    buildInputs = [
      actualHello
      which
    ];

    unpackPhase = "true";

    installPhase = ''
      mkdir -p "$out/bin"
      echo "#! ${stdenv.shell}" >> "$out/bin/hello"
      echo "exec $(which hello)" >> "$out/bin/hello"
      chmod 0755 "$out/bin/hello"
    '';
  };
in
wrappedHello
```

Notice that the wrappedHello derivation finds the `hello` binary from the `PATH`. This works because stdenv contains something like:

```sh
pkgs=""
for i in $buildInputs; do
    findInputs $i
done
```

where `findInputs` is defined like:

```sh
findInputs() {
    local pkg=$1

    ## Don't need to repeat already processed package
    case $pkgs in
        *\ $pkg\ *)
            return 0
            ;;
    esac

    pkgs="$pkgs $pkg "

    ## More goes here in reality that we can ignore for now.
}
```

then after this is run:

```sh
for i in $pkgs; do
    addToEnv $i
done
```

where `addToEnv` is defined like:

```sh
addToEnv() {
    local pkg=$1

    if test -d $1/bin; then
        addToSearchPath _PATH $1/bin
    fi

    ## More goes here in reality that we can ignore for now.
}
```

The `addToSearchPath` call adds `$1/bin` to `_PATH` if the former exists (code [here](https://github.com/NixOS/nixpkgs/blob/6675f0a52c0962042a1000c7f20e887d0d26ae25/pkgs/stdenv/generic/setup.sh#L60-L73)). Once all the packages in `buildInputs` have been processed, then content of `_PATH` is added to `PATH`, as follows:

```sh
PATH="${_PATH-}${_PATH:+${PATH:+:}}$PATH"
```

With the real `hello` on the `PATH`, the `installPhase` should hopefully make sense.

## The `propagatedBuildInputs` Attribute

The `buildInputs` covers direct dependencies, but what about indirect dependencies where one package needs a second package which needs a third? Nix itself handles this just fine, understanding various dependency closures as covered in previous builds. But what about the conveniences that `buildInputs` provides, namely accumulating in `pkgs` environment variable and inclusion of `«pkg»/bin` directories on the `PATH`? For this, stdenv provides the `propagatedBuildInputs`:

```nix
let

  nixpkgs = import <nixpkgs> { };

  inherit (nixpkgs) stdenv fetchurl which;

  actualHello = stdenv.mkDerivation {
    name = "hello-2.3";

    src = fetchurl {
      url = "mirror://gnu/hello/hello-2.3.tar.bz2";
      sha256 = "0c7vijq8y68bpr7g6dh1gny0bff8qq81vnp4ch8pjzvg56wb3js1";
    };
  };

  intermediary = stdenv.mkDerivation {
    name = "middle-man";

    propagatedBuildInputs = [ actualHello ];

    unpackPhase = "true";

    installPhase = ''
      mkdir -p "$out"
    '';
  };

  wrappedHello = stdenv.mkDerivation {
    name = "hello-wrapper";

    buildInputs = [
      intermediary
      which
    ];

    unpackPhase = "true";

    installPhase = ''
      mkdir -p "$out/bin"
      echo "#! ${stdenv.shell}" >> "$out/bin/hello"
      echo "exec $(which hello)" >> "$out/bin/hello"
      chmod 0755 "$out/bin/hello"
    '';
  };
in
wrappedHello
```

See how the intermediate package has a `propagatedBuildInputs` dependency, but the wrapper only needs a `buildInputs` dependency on the intermediary.

How does this work? You might think we do something in Nix, but actually it's done not at eval time but at build time in bash. let's look at part of the `fixupPhase` of stdenv:

```sh
fixupPhase() {

    ## Elided

    if test -n "$propagatedBuildInputs"; then
        mkdir -p "$out/nix-support"
        echo "$propagatedBuildInputs" > "$out/nix-support/propagated-build-inputs"
    fi

    ## Elided

}
```

This dumps the propagated build inputs in a so-named file in `$out/nix-support/`. Then, back in `findInputs` look at the lines at the bottom we elided before:

```sh
findInputs() {
    local pkg=$1

    ## More goes here in reality that we can ignore for now.

    if test -f $pkg/nix-support/propagated-build-inputs; then
        for i in $(cat $pkg/nix-support/propagated-build-inputs); do
            findInputs $i
        done
    fi
}
```

See how `findInputs` is actually recursive, looking at the propagated build inputs of each dependency, and those dependencies' propagated build inputs, etc.

We actually simplified the `findInputs` call site from before; `propagatedBuildInputs` is also looped over in reality:

```sh
pkgs=""
for i in $buildInputs $propagatedBuildInputs; do
    findInputs $i
done
```

This demonstrates an important point. For the _current_ package alone, it doesn't matter whether a dependency is propagated or not. It will be processed the same way: called with `findInputs` and `addToEnv`. (The packages discovered by `findInputs`, which are also accumulated in `pkgs` and passed to `addToEnv`, are also the same in both cases.) Downstream however, it certainly does matter because only the propagated immediate dependencies are put in the `$out/nix-support/propagated-build-inputs`.

## Setup Hooks

As we mentioned above, sometimes dependencies need to influence the packages that use them in ways other than just _being_ a dependency. [^1] `propagatedBuildInputs` can actually be seen as an example of this: packages using that are effectively "injecting" those dependencies as extra `buildInputs` in their downstream dependents. But in general, a dependency might affect the packages it depends on in arbitrary ways. _Arbitrary_ is the key word here. We could teach `setup.sh` things about upstream packages like `«pkg»/nix-support/propagated-build-inputs`, but not arbitrary interactions.

Setup hooks are the basic building block we have for this. In nixpkgs, a "hook" is basically a bash callback, and a setup hook is no exception. Let's look at the last part of `findInputs` we haven't covered:

```sh
findInputs() {
    local pkg=$1

    ## More goes here in reality that we can ignore for now.

    if test -f $pkg/nix-support/setup-hook; then
        source $pkg/nix-support/setup-hook
    fi

    ## More goes here in reality that we can ignore for now.

}
```

If a package includes the path `«pkg»/nix-support/setup-hook`, it will be sourced by any stdenv-based build including that as a dependency.

This is strictly more general than any of the other mechanisms introduced in this chapter. For example, try writing a setup hook that has the same effect as a _propagatedBuildInputs_ entry. One can almost think of this as an escape hatch around Nix's normal isolation guarantees, and the principle that dependencies are immutable and inert. We're not actually doing something unsafe or modifying dependencies, but we are allowing arbitrary ad-hoc behavior. For this reason, setup-hooks should only be used as a last resort.

## Environment Hooks

As a final convenience, we have environment hooks. Recall in [Pill 12](12-inputs-design-pattern.md) how we created `NIX_CFLAGS_COMPILE` for `-I` flags and `NIX_LDFLAGS` for `-L` flags, in a similar manner to how we prepared the `PATH`. One point of ugliness was how anti-modular this was. It makes sense to build the `PATH` in a generic builder, because the `PATH` is used by the shell, and the generic builder is intrinsically tied to the shell. But `-I` and `-L` flags are only relevant to the C compiler. The stdenv isn't wedded to including a C compiler (though it does by default), and there are other compilers too which may take completely different flags.

As a first step, we can move that logic to a setup hook on the C compiler; indeed that's just what we do in CC Wrapper. [^2] But this pattern comes up fairly often, so somebody decided to add some helper support to reduce boilerplate.

The other half of `addToEnv` is:

```sh
addToEnv() {
    local pkg=$1

    ## More goes here in reality that we can ignore for now.

    # Run the package-specific hooks set by the setup-hook scripts.
    for i in "${envHooks[@]}"; do
        $i $pkg
    done
}
```

Functions listed in `envHooks` are applied to every package passed to `addToEnv`. One can write a setup hook like:

```sh
anEnvHook() {
    local pkg=$1

    echo "I'm depending on \"$pkg\""
}

envHooks+=(anEnvHook)
```

and if one dependency has that setup hook then all of them will be so `echo`ed. Allowing dependencies to learn about their _sibling_ dependencies is exactly what compilers need.

## Next pill...

...I'm not sure! We could talk about the additional dependency types and hooks which cross compilation necessitates, building on our knowledge here to cover stdenv as it works today. We could talk about how nixpkgs is bootstrapped. Or we could talk about how `localSystem` and `crossSystem` are elaborated into the `buildPlatform`, `hostPlatform`, and `targetPlatform` each bootstrapping stage receives. Let us know which most interests you!

[^1]: We can now be precise and consider what `addToEnv` does alone the minimal treatment of a dependency: i.e. a package that is _just_ a dependency would _only_ have `addToEnv` applied to it.

[^2]: It was called [GCC Wrapper](https://github.com/NixOS/nixpkgs/tree/6675f0a52c0962042a1000c7f20e887d0d26ae25/pkgs/build-support/gcc-wrapper) in the version of nixpkgs suggested for following along in this pill; Darwin and Clang support hadn't yet motivated the rename.
