# Working Derivation

## Introduction

Welcome to the seventh nix pill. In the previous [sixth pill](06-our-first-derivation.md) we introduced the notion of derivation in the Nix language --- how to define a raw derivation and how to (try to) build it.

In this post we continue along the path, by creating a derivation that actually builds something. Then, we try to package a real program: we compile a simple C file and create a derivation out of it, given a blessed toolchain.

I remind you how to enter the Nix environment: `source ~/.nix-profile/etc/profile.d/nix.sh`

## Using a script as a builder

What's the easiest way to run a sequence of commands for building something? A bash script. We write a custom bash script, and we want it to be our builder. Given a `builder.sh`, we want the derivation to run `bash builder.sh`.

We don't use hash bangs in `builder.sh`, because at the time we are writing it we do not know the path to bash in the nix store. Yes, even bash is in the nix store, everything is there.

We don't even use /usr/bin/env, because then we lose the cool stateless property of Nix. Not to mention that `PATH` gets cleared when building, so it wouldn't find bash anyway.

In summary, we want the builder to be bash, and pass it an argument, `builder.sh`. Turns out the `derivation` function accepts an optional `args` attribute which is used to pass arguments to the builder executable.

First of all, let's write our `builder.sh` in the current directory:

```sh
declare -xp
echo foo > $out
```

The command `declare -xp` lists exported variables (`declare` is a builtin bash function). As we covered in the previous pill, Nix computes the output path of the derivation. The resulting `.drv` file contains a list of environment variables passed to the builder. One of these is `$out`.

What we have to do is create something in the path `$out`, be it a file or a directory. In this case we are creating a file.

In addition, we print out the environment variables during the build process. We cannot use env for this, because env is part of coreutils and we don't have a dependency to it yet. We only have bash for now.

Like for coreutils in the previous pill, we get a blessed bash for free from our magic nixpkgs stuff:

```console
nix-repl> :l <nixpkgs>
Added 3950 variables.
nix-repl> "${bash}"
"/nix/store/ihmkc7z2wqk3bbipfnlh0yjrlfkkgnv6-bash-4.2-p45"
```

So with the usual trick, we can refer to bin/bash and create our derivation:

```console
nix-repl> d = derivation { name = "foo"; builder = "${bash}/bin/bash"; args = [ ./builder.sh ]; system = builtins.currentSystem; }
nix-repl> :b d
[1 built, 0.0 MiB DL]

this derivation produced the following outputs:
  out -> /nix/store/gczb4qrag22harvv693wwnflqy7lx5pb-foo
```

We did it! The contents of `/nix/store/w024zci0x1hh1wj6gjq0jagkc1sgrf5r-foo` is really foo. We've built our first derivation.

Note that we used `./builder.sh` and not `"./builder.sh"`. This way, it is parsed as a path, and Nix performs some magic which we will cover later. Try using the string version and you will find that it cannot find `builder.sh`. This is because it tries to find it relative to the temporary build directory.

## The builder environment

We can use `nix-store --read-log` to see the logs our builder produced:

```console
$ nix-store --read-log /nix/store/gczb4qrag22harvv693wwnflqy7lx5pb-foo
declare -x HOME="/homeless-shelter"
declare -x NIX_BUILD_CORES="4"
declare -x NIX_BUILD_TOP="/tmp/nix-build-foo.drv-0"
declare -x NIX_LOG_FD="2"
declare -x NIX_STORE="/nix/store"
declare -x OLDPWD
declare -x PATH="/path-not-set"
declare -x PWD="/tmp/nix-build-foo.drv-0"
declare -x SHLVL="1"
declare -x TEMP="/tmp/nix-build-foo.drv-0"
declare -x TEMPDIR="/tmp/nix-build-foo.drv-0"
declare -x TMP="/tmp/nix-build-foo.drv-0"
declare -x TMPDIR="/tmp/nix-build-foo.drv-0"
declare -x builder="/nix/store/q1g0rl8zfmz7r371fp5p42p4acmv297d-bash-4.4-p19/bin/bash"
declare -x name="foo"
declare -x out="/nix/store/gczb4qrag22harvv693wwnflqy7lx5pb-foo"
declare -x system="x86_64-linux"
```

Let's inspect those environment variables printed during the build process.

- `$HOME` is not your home directory, and `/homeless-shelter` doesn't exist at all. We force packages not to depend on `$HOME` during the build process.

- `$PATH` plays the same game as `$HOME`

- `$NIX_BUILD_CORES` and `$NIX_STORE` are [nix configuration options](https://nix.dev/manual/nix/stable/command-ref/conf-file)

- `$PWD` and `$TMP` clearly show that nix created a temporary build directory

- Then `$builder`, `$name`, `$out`, and `$system` are variables set due to the .drv file's contents.

And that's how we were able to use `$out` in our derivation and put stuff in it. It's like Nix reserved a slot in the nix store for us, and we must fill it.

In terms of autotools, `$out` will be the `--prefix` path. Yes, not the make `DESTDIR`, but the `--prefix`. That's the essence of stateless packaging. You don't install the package in a global common path under `/`, you install it in a local isolated path under your nix store slot.

## The .drv contents

We added something else to the derivation this time: the args attribute. Let's see how this changed the .drv compared to the previous pill:

```console
$ nix derivation show /nix/store/i76pr1cz0za3i9r6xq518bqqvd2raspw-foo.drv
{
  "/nix/store/i76pr1cz0za3i9r6xq518bqqvd2raspw-foo.drv": {
    "outputs": {
      "out": {
        "path": "/nix/store/gczb4qrag22harvv693wwnflqy7lx5pb-foo"
      }
    },
    "inputSrcs": [
      "/nix/store/lb0n38r2b20r8rl1k45a7s4pj6ny22f7-builder.sh"
    ],
    "inputDrvs": {
      "/nix/store/hcgwbx42mcxr7ksnv0i1fg7kw6jvxshb-bash-4.4-p19.drv": [
        "out"
      ]
    },
    "platform": "x86_64-linux",
    "builder": "/nix/store/q1g0rl8zfmz7r371fp5p42p4acmv297d-bash-4.4-p19/bin/bash",
    "args": [
      "/nix/store/lb0n38r2b20r8rl1k45a7s4pj6ny22f7-builder.sh"
    ],
    "env": {
      "builder": "/nix/store/q1g0rl8zfmz7r371fp5p42p4acmv297d-bash-4.4-p19/bin/bash",
      "name": "foo",
      "out": "/nix/store/gczb4qrag22harvv693wwnflqy7lx5pb-foo",
      "system": "x86_64-linux"
    }
  }
}
```

Much like the usual .drv, except that there's a list of arguments in there passed to the builder (bash) with `builder.sh`... In the nix store..? Nix automatically copies files or directories needed for the build into the store to ensure that they are not changed during the build process and that the deployment is stateless and independent of the building machine. `builder.sh` is not only in the arguments passed to the builder, it's also in the input sources.

Given that `builder.sh` is a plain file, it has no .drv associated with it. The store path is computed based on the filename and on the hash of its contents. Store paths are covered in detail in [a later pill](18-nix-store-paths.md).

## Packaging a simple C program

Start off by writing a simple C program called `simple.c`:

```c
void main() {
    puts("Simple!");
}
```

And its `simple_builder.sh`:

```sh
export PATH="$coreutils/bin:$gcc/bin"
mkdir $out
gcc -o $out/simple $src
```

Don't worry too much about where those variables come from yet; let's write the derivation and build it:

```console
nix-repl> :l <nixpkgs>
nix-repl> simple = derivation { name = "simple"; builder = "${bash}/bin/bash"; args = [ ./simple_builder.sh ]; gcc = gcc; coreutils = coreutils; src = ./simple.c; system = builtins.currentSystem; }
nix-repl> :b simple
this derivation produced the following outputs:

  out -> /nix/store/ni66p4jfqksbmsl616llx3fbs1d232d4-simple
```

Now you can run `/nix/store/ni66p4jfqksbmsl616llx3fbs1d232d4-simple/simple` in your shell.

## Explanation

We added two new attributes to the derivation call, `gcc` and `coreutils`. In `gcc = gcc;`, the name on the left is the name in the derivation set, and the name on the right refers to the gcc derivation from nixpkgs. The same applies for coreutils.

We also added the `src` attribute, nothing magical --- it's just a name, to which the path `./simple.c` is assigned. Like `simple-builder.sh`, `simple.c` will be added to the store.

The trick: every attribute in the set passed to `derivation` will be converted to a string and passed to the builder as an environment variable. This is how the builder gains access to coreutils and gcc: when converted to strings, the derivations evaluate to their output paths, and appending `/bin` to these leads us to their binaries.

The same goes for the `src` variable. `$src` is the path to `simple.c` in the nix store. As an exercise, pretty print the .drv file. You'll see `simple_builder.sh` and `simple.c` listed in the input derivations, along with bash, gcc and coreutils .drv files. The newly added environment variables described above will also appear.

In `simple_builder.sh` we set the `PATH` for gcc and coreutils binaries, so that our build script can find the necessary utilities like mkdir and gcc.

We then create `$out` as a directory and place the binary inside it. Note that gcc is found via the `PATH` environment variable, but it could equivalently be referenced explicitly using `$gcc/bin/gcc`.

## Enough of `nix repl`

Drop out of nix repl and write a file `simple.nix`:

```nix
let
  pkgs = import <nixpkgs> { };
in
derivation {
  name = "simple";
  builder = "${pkgs.bash}/bin/bash";
  args = [ ./simple_builder.sh ];
  gcc = pkgs.gcc;
  coreutils = pkgs.coreutils;
  src = ./simple.c;
  system = builtins.currentSystem;
}
```

Now you can build it with `nix-build simple.nix`. This will create a symlink `result` in the current directory, pointing to the out path of the derivation.

nix-build does two jobs:

- [nix-instantiate](https://nix.dev/manual/nix/stable/command-ref/nix-instantiate): parse and evaluate `simple.nix` and return the .drv file corresponding to the parsed derivation set

- [`nix-store -r`](https://nix.dev/manual/nix/stable/command-ref/nix-store/realise): realise the .drv file, which actually builds it.

Finally, it creates the symlink.

In the second line of `simple.nix`, we have an `import` function call. Recall that `import` accepts one argument, a nix file to load. In this case, the contents of the file evaluate to a function.

Afterwards, we call the function with the empty set. We saw this already in [the fifth pill](05-functions-and-imports.md). To reiterate: `import <nixpkgs> {}` is calling two functions, not one. Reading it as `(import <nixpkgs>) {}` makes this clearer.

The value returned by the nixpkgs function is a set; more specifically, it's a set of derivations. Calling `import <nixpkgs> {}` into a `let`-expression creates the local variable `pkgs` and brings it into scope. This has an effect similar to the `:l <nixpkgs>` we used in nix repl, in that it allows us to easily access derivations such as `bash`, `gcc`, and `coreutils`, but those derivations will have to be explicitly referred to as members of the `pkgs` set (e.g., `pkgs.bash` instead of just `bash`).

Below is a revised version of the `simple.nix` file, using the `inherit` keyword:

```nix
let
  pkgs = import <nixpkgs> { };
in
derivation {
  name = "simple";
  builder = "${pkgs.bash}/bin/bash";
  args = [ ./simple_builder.sh ];
  inherit (pkgs) gcc coreutils;
  src = ./simple.c;
  system = builtins.currentSystem;
}
```

Here we also take the opportunity to introduce the [`inherit` keyword](https://nix.dev/manual/nix/stable/language/constructs#inheriting-attributes). `inherit foo;` is equivalent to `foo = foo;`. Similarly, `inherit gcc coreutils;` is equivalent to `gcc = gcc; coreutils = coreutils;`. Lastly, `inherit (pkgs) gcc coreutils;` is equivalent to `gcc = pkgs.gcc; coreutils = pkgs.coreutils;`.

This syntax only makes sense inside sets. There's no magic involved, it's simply a convenience to avoid repeating the same name for both the attribute name and the value in scope.

## Next pill

We will generalize the builder. You may have noticed that we wrote two separate `builder.sh` scripts in this post. We would like to have a generic builder script instead, especially since each build script goes in the nix store: a bit of a waste.

_Is it really that hard to package stuff in Nix? No_, here we're studying the fundamentals of Nix.
