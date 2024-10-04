# Generic Builders

Welcome to the 8th Nix pill. In the previous [7th pill](07-working-derivation.md) we successfully built a derivation. We wrote a builder script that compiled a C file and installed the binary under the nix store.

In this post, we will generalize the builder script, write a Nix expression for [GNU hello world](https://www.gnu.org/software/hello/) and create a wrapper around the derivation built-in function.

## Packaging GNU hello world

In the previous pill we packaged a simple .c file, which was being compiled with a raw gcc call. That's not a good example of a project. Many use autotools, and since we're going to generalize our builder, it would be better to do it with the most used build system.

[GNU hello world](https://www.gnu.org/software/hello/), despite its name, is a simple yet complete project which uses autotools. Fetch the latest tarball here: <https://ftp.gnu.org/gnu/hello/hello-2.12.1.tar.gz>.

Let's create a builder script for GNU hello world, hello_builder.sh:

```sh
export PATH="$gnutar/bin:$gcc/bin:$gnumake/bin:$coreutils/bin:$gawk/bin:$gzip/bin:$gnugrep/bin:$gnused/bin:$bintools/bin"
tar -xzf $src
cd hello-2.12.1
./configure --prefix=$out
make
make install
```

And the derivation hello.nix:

```nix
let
  pkgs = import <nixpkgs> { };
in
derivation {
  name = "hello";
  builder = "${pkgs.bash}/bin/bash";
  args = [ ./hello_builder.sh ];
  inherit (pkgs)
    gnutar
    gzip
    gnumake
    gcc
    coreutils
    gawk
    gnused
    gnugrep
    ;
  bintools = pkgs.binutils.bintools;
  src = ./hello-2.12.1.tar.gz;
  system = builtins.currentSystem;
}
```

<div class="info">
<h4>Nix on darwin</h4>

Darwin (i.e. macOS) builds typically use `clang` rather than `gcc` for a C compiler. We can adapt this early example for darwin by using this modified version of `hello.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
derivation {
  name = "hello";
  builder = "${pkgs.bash}/bin/bash";
  args = [ ./hello_builder.sh ];
  inherit (pkgs)
    gnutar
    gzip
    gnumake
    coreutils
    gawk
    gnused
    gnugrep
    ;
  gcc = pkgs.clang;
  bintools = pkgs.clang.bintools.bintools_bin;
  src = ./hello-2.12.1.tar.gz;
  system = builtins.currentSystem;
}
```

Later, we will show how Nix can automatically handle these differences. For now, please be just aware that changes similar to the above may be needed in what follows.

</div>

Now build it with `nix-build hello.nix` and you can launch `result/bin/hello`. Nothing easier, but do we have to create a builder.sh for each package? Do we always have to pass the dependencies to the `derivation` function?

Please note the `--prefix=$out` we were talking about in the [previous pill](07-working-derivation.md).

## A generic builder

Let's create a generic `builder.sh` for autotools projects:

```sh
set -e
unset PATH
for p in $buildInputs; do
    export PATH=$p/bin${PATH:+:}$PATH
done

tar -xf $src

for d in *; do
    if [ -d "$d" ]; then
        cd "$d"
        break
    fi
done

./configure --prefix=$out
make
make install
```

What do we do here?

1.  Exit the build on any error with `set -e`.

2.  First `unset PATH`, because it's initially set to a non-existent path.

3.  We'll see this below in detail, however for each path in `$buildInputs`, we append `bin` to `PATH`.

4.  Unpack the source.

5.  Find a directory where the source has been unpacked and `cd` into it.

6.  Once we're set up, compile and install.

As you can see, there's no reference to "hello" in the builder anymore. It still makes several assumptions, but it's certainly more generic.

Now let's rewrite `hello.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
derivation {
  name = "hello";
  builder = "${pkgs.bash}/bin/bash";
  args = [ ./builder.sh ];
  buildInputs = with pkgs; [
    gnutar
    gzip
    gnumake
    gcc
    coreutils
    gawk
    gnused
    gnugrep
    binutils.bintools
  ];
  src = ./hello-2.12.1.tar.gz;
  system = builtins.currentSystem;
}
```

All clear, except that buildInputs. However it's easier than any black magic you are thinking of at this moment.

Nix is able to convert a list to a string. It first converts the elements to strings, and then concatenates them separated by a space:

```console
nix-repl> builtins.toString 123
"123"
nix-repl> builtins.toString [ 123 456 ]
"123 456"
```

Recall that derivations can be converted to a string, hence:

```console
nix-repl> :l <nixpkgs>
Added 3950 variables.
nix-repl> builtins.toString gnugrep
"/nix/store/g5gdylclfh6d224kqh9sja290pk186xd-gnugrep-2.14"
nix-repl> builtins.toString [ gnugrep gnused ]
"/nix/store/g5gdylclfh6d224kqh9sja290pk186xd-gnugrep-2.14 /nix/store/krgdc4sknzpw8iyk9p20lhqfd52kjmg0-gnused-4.2.2"
```

Simple! The buildInputs variable is a string with out paths separated by space, perfect for bash usage in a for loop.

## A more convenient derivation function

We managed to write a builder that can be used for multiple autotools projects. But in the hello.nix expression we are specifying tools that are common to more projects; we don't want to pass them every time.

A natural approach would be to create a function that accepts an attribute set, similar to the one used by the derivation function, and merge it with another attribute set containing values common to many projects.

Create `autotools.nix`:

```nix
pkgs: attrs:
let
  defaultAttrs = {
    builder = "${pkgs.bash}/bin/bash";
    args = [ ./builder.sh ];
    baseInputs = with pkgs; [
      gnutar
      gzip
      gnumake
      gcc
      coreutils
      gawk
      gnused
      gnugrep
      binutils.bintools
    ];
    buildInputs = [ ];
    system = builtins.currentSystem;
  };
in
derivation (defaultAttrs // attrs)
```

Ok now we have to remember a little about [Nix functions](05-functions-and-imports.md). The whole nix expression of this `autotools.nix` file will evaluate to a function. This function accepts a parameter `pkgs`, then returns a function which accepts a parameter `attrs`.

The body of the function is simple, yet at first sight it might be hard to grasp:

1.  First drop in the scope the magic `pkgs` attribute set.

2.  Within a let expression we define a helper variable, `defaultAttrs`, which serves as a set of common attributes used in derivations.

3.  Finally we create the derivation with that strange expression, (`defaultAttrs // attrs`).

The [// operator](https://nix.dev/manual/nix/stable/language/operators.html#update) is an operator between two sets. The result is the union of the two sets. In case of conflicts between attribute names, the value on the right set is preferred.

So we use `defaultAttrs` as base set, and add (or override) the attributes from `attrs`.

A couple of examples ought to be enough to clear out the behavior of the operator:

```console
nix-repl> { a = "b"; } // { c = "d"; }
{ a = "b"; c = "d"; }
nix-repl> { a = "b"; } // { a = "c"; }
{ a = "c"; }
```

**Exercise:** Complete the new `builder.sh` by adding `$baseInputs` in the `for` loop together with `$buildInputs`. As you noticed, we passed that new variable in the derivation. Instead of merging buildInputs with the base ones, we prefer to preserve buildInputs as seen by the caller, so we keep them separated. Just a matter of choice.

Then we rewrite `hello.nix` as follows:

```nix
let
  pkgs = import <nixpkgs> { };
  mkDerivation = import ./autotools.nix pkgs;
in
mkDerivation {
  name = "hello";
  src = ./hello-2.12.1.tar.gz;
}
```

Finally! We got a very simple description of a package! Below are a couple of remarks that you may find useful as you're continuing to understand the nix language:

- We assigned to pkgs the import that we did in the previous expressions in the "with". Don't be afraid, it's that straightforward.

- The mkDerivation variable is a nice example of partial application, look at it as (`import ./autotools.nix`) `pkgs`. First we import the expression, then we apply the `pkgs` parameter. That will give us a function that accepts the attribute set `attrs`.

- We create the derivation specifying only name and src. If the project eventually needed other dependencies to be in PATH, then we would simply add those to buildInputs (not specified in hello.nix because empty).

Note we didn't use any other library. Special C flags may be needed to find include files of other libraries at compile time, and ld flags at link time.

## Conclusion

Nix gives us the bare metal tools for creating derivations, setting up a build environment and storing the result in the nix store.

Out of this pill we managed to create a generic builder for autotools projects, and a function `mkDerivation` that composes by default the common components used in autotools projects instead of repeating them in all the packages we would write.

We are familiarizing ourselves with the way a Nix system grows up: it's about creating and composing derivations with the Nix language.

Analogy: in C you create objects in the heap, and then you compose them inside new objects. Pointers are used to refer to other objects.

In Nix you create derivations stored in the nix store, and then you compose them by creating new derivations. Store paths are used to refer to other derivations.

## Next pill

...we will talk a little about runtime dependencies. Is the GNU hello world package self-contained? What are its runtime dependencies? We only specified build dependencies by means of using other derivations in the "hello" derivation.
