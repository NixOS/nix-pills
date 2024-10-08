# Our First Derivation

Welcome to the sixth Nix pill. In the previous [fifth pill](05-functions-and-imports.md) we introduced functions and imports. Functions and imports are very simple concepts that allow for building complex abstractions and composition of modules to build a flexible Nix system.

In this post we finally arrived to writing a derivation. Derivations are the building blocks of a Nix system, from a file system view point. The Nix language is used to describe such derivations.

I remind you how to enter the Nix environment: `source ~/.nix-profile/etc/profile.d/nix.sh`

## The derivation function

The [derivation built-in function](https://nix.dev/manual/nix/stable/language/derivations) is used to create derivations. I invite you to read the link in the Nix manual about the derivation built-in. A derivation from a Nix language view point is simply a set, with some attributes. Therefore you can pass the derivation around with variables like anything else.

That's where the real power comes in.

The `derivation` function receives a set as its first argument. This set requires at least the following three attributes:

- name: the name of the derivation. In the nix store the format is hash-name, that's the name.

- system: is the name of the system in which the derivation can be built. For example, x86_64-linux.

- builder: is the binary program that builds the derivation.

First of all, what's the name of our system as seen by nix?

```console
nix-repl> builtins.currentSystem
"x86_64-linux"
```

Let's try to fake the name of the system:

```console
nix-repl> d = derivation { name = "myname"; builder = "mybuilder"; system = "mysystem"; }
nix-repl> d
«derivation /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv»
```

Oh oh, what's that? Did it build the derivation? No it didn't, but it **did create the .drv file**. `nix repl` does not build derivations unless you tell it to do so.

## Digression about .drv files

What's that `.drv` file? It is the specification of how to build the derivation, without all the Nix language fuzz.

Before continuing, some analogies with the C language:

- `.nix` files are like `.c` files.

- `.drv` files are intermediate files like `.o` files. The `.drv` describes how to build a derivation; it's the bare minimum information.

- out paths are then the product of the build.

Both drv paths and out paths are stored in the nix store as you can see.

What's in that `.drv` file? You can read it, but it's better to pretty print it:

<div class="info">

Note: If your version of nix doesn't have `nix derivation show`, use `nix show-derivation` instead.

</div>

```console
$ nix derivation show /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv
{
  "/nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv": {
    "outputs": {
      "out": {
        "path": "/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname"
      }
    },
    "inputSrcs": [],
    "inputDrvs": {},
    "platform": "mysystem",
    "builder": "mybuilder",
    "args": [],
    "env": {
      "builder": "mybuilder",
      "name": "myname",
      "out": "/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname",
      "system": "mysystem"
    }
  }
}
```

Ok, we can see there's an out path, but it does not exist yet. We never told Nix to build it, but we know beforehand where the build output will be. Why?

Think, if Nix ever built the derivation just because we accessed it in Nix, we would have to wait a long time if it was, say, Firefox. That's why Nix let us know the path beforehand and kept evaluating the Nix expressions, but it's still empty because no build was ever made.

Important: the hash of the out path is based solely on the input derivations in the current version of Nix, not on the contents of the build product. It's possible however to have [content-addressable](https://en.wikipedia.org/wiki/Content-addressable_storage) derivations for e.g. tarballs as we'll see later on.

Many things are empty in that `.drv`, however I'll write a summary of the [.drv format](http://nixos.org/~eelco/pubs/phd-thesis.pdf) for you:

1.  The output paths (there can be multiple ones). By default nix creates one out path called "out".

2.  The list of input derivations. It's empty because we are not referring to any other derivation. Otherwise, there would be a list of other .drv files.

3.  The system and the builder executable (yes, it's a fake one).

4.  Then a list of environment variables passed to the builder.

That's it, the minimum necessary information to build our derivation.

Important note: the environment variables passed to the builder are just those you see in the .drv plus some other Nix related configuration (number of cores, temp dir, ...). The builder will not inherit any variable from your running shell, otherwise builds would suffer from [non-determinism](https://wiki.debian.org/ReproducibleBuilds).

Back to our fake derivation.

Let's build our really fake derivation:

```console
nix-repl> d = derivation { name = "myname"; builder = "mybuilder"; system = "mysystem"; }
nix-repl> :b d
[...]
these derivations will be built:
  /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv
building path(s) `/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname'
error: a `mysystem' is required to build `/nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv', but I am a `x86_64-linux'
```

The `:b` is a `nix repl` specific command to build a derivation. You can see more commands with `:?` . So in the output you can see that it takes the `.drv` as information on how to build the derivation. Then it says it's trying to produce our out path. Finally the error we were waiting for: that derivation can't be built on our system.

We're doing the build inside `nix repl`, but what if we don't want to use `nix repl`? You can **realise** a `.drv` with:

```console
$ nix-store -r /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv
```

You will get the same output as before.

Let's fix the system attribute:

```console
nix-repl> d = derivation { name = "myname"; builder = "mybuilder"; system = builtins.currentSystem; }
nix-repl> :b d
[...]
build error: invalid file name `mybuilder'
```

A step forward: of course, that `mybuilder` executable does not really exist. Stop for a moment.

## What's in a derivation set

It is useful to start by inspecting the return value from the derivation function. In this case, the returned value is a plain set:

```console
nix-repl> d = derivation { name = "myname"; builder = "mybuilder"; system = "mysystem"; }
nix-repl> builtins.isAttrs d
true
nix-repl> builtins.attrNames d
[ "all" "builder" "drvAttrs" "drvPath" "name" "out" "outPath" "outputName" "system" "type" ]
```

You can guess what `builtins.isAttrs` does; it returns true if the argument is a set. While `builtins.attrNames` returns a list of keys of the given set. Some kind of reflection, you might say.

Start from drvAttrs:

```console
nix-repl> d.drvAttrs
{ builder = "mybuilder"; name = "myname"; system = "mysystem"; }
```

That's basically the input we gave to the derivation function. Also the `d.name`, `d.system` and `d.builder` attributes are exactly the ones we gave as input.

```console
nix-repl> (d == d.out)
true
```

So out is just the derivation itself, it seems weird but the reason is that we only have one output from the derivation. That's also the reason why `d.all` is a singleton. We'll see multiple outputs later.

The `d.drvPath` is the path of the `.drv` file: `/nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv`.

Something interesting is the `type` attribute. It's `"derivation"`. Nix does add a little of magic to sets with type derivation, but not that much. To help you understand, you can create yourself a set with that type, it's a simple set:

```console
nix-repl> { type = "derivation"; }
«derivation ???»
```

Of course it has no other information, so Nix doesn't know what to say :-) But you get it, the `type = "derivation"` is just a convention for Nix and for us to understand the set is a derivation.

When writing packages, we are interested in the outputs. The other metadata is needed for Nix to know how to create the drv path and the out path.

The `outPath` attribute is the build path in the nix store: `/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname`.

## Referring to other derivations

Just like dependencies in other package managers, how do we refer to other packages? How do we refer to other derivations in terms of files on the disk? We use the `outPath`. The `outPath` describes the location of the files of that derivation. To make it more convenient, Nix is able to do a conversion from a derivation set to a string.

```console
nix-repl> d.outPath
"/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname"
nix-repl> builtins.toString d
"/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname"
```

Nix does the "set to string conversion" as long as there is the `outPath` attribute (much like a toString method in other languages):

```console
nix-repl> builtins.toString { outPath = "foo"; }
"foo"
nix-repl> builtins.toString { a = "b"; }
error: cannot coerce a set to a string, at (string):1:1
```

Say we want to use binaries from coreutils (ignore the nixpkgs etc.):

```console
nix-repl> :l <nixpkgs>
Added 3950 variables.
nix-repl> coreutils
«derivation /nix/store/1zcs1y4n27lqs0gw4v038i303pb89rw6-coreutils-8.21.drv»
nix-repl> builtins.toString coreutils
"/nix/store/8w4cbiy7wqvaqsnsnb3zvabq1cp2zhyz-coreutils-8.21"
```

Apart from the nixpkgs stuff, just think we added to the scope a series of variables. One of them is coreutils. It is the derivation of the coreutils package you all know of from other Linux distributions. It contains basic binaries for GNU/Linux systems (you may have multiple derivations of coreutils in the nix store, no worries):

```console
$ ls /nix/store/*coreutils*/bin
[...]
```

I remind you, inside strings it's possible to interpolate Nix expressions with `${...}`:

```console
nix-repl> "${d}"
"/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname"
nix-repl> "${coreutils}"
"/nix/store/8w4cbiy7wqvaqsnsnb3zvabq1cp2zhyz-coreutils-8.21"
```

That's very convenient, because then we could refer to e.g. the bin/true binary like this:

```console
nix-repl> "${coreutils}/bin/true"
"/nix/store/8w4cbiy7wqvaqsnsnb3zvabq1cp2zhyz-coreutils-8.21/bin/true"
```

## An almost working derivation

In the previous attempt we used a fake builder, `mybuilder` which obviously does not exist. But we can use for example bin/true, which always exits with 0 (success).

```console
nix-repl> :l <nixpkgs>
nix-repl> d = derivation { name = "myname"; builder = "${coreutils}/bin/true"; system = builtins.currentSystem; }
nix-repl> :b d
[...]
builder for `/nix/store/qyfrcd53wmc0v22ymhhd5r6sz5xmdc8a-myname.drv' failed to produce output path `/nix/store/ly2k1vswbfmswr33hw0kf0ccilrpisnk-myname'
```

Another step forward, it executed the builder (bin/true), but the builder did not create the out path of course, it just exited with 0.

Obvious note: every time we change the derivation, a new hash is created.

Let's examine the new `.drv` now that we referred to another derivation:

```console
$ nix derivation show /nix/store/qyfrcd53wmc0v22ymhhd5r6sz5xmdc8a-myname.drv
{
  "/nix/store/qyfrcd53wmc0v22ymhhd5r6sz5xmdc8a-myname.drv": {
    "outputs": {
      "out": {
        "path": "/nix/store/ly2k1vswbfmswr33hw0kf0ccilrpisnk-myname"
      }
    },
    "inputSrcs": [],
    "inputDrvs": {
      "/nix/store/hixdnzz2wp75x1jy65cysq06yl74vx7q-coreutils-8.29.drv": [
        "out"
      ]
    },
    "platform": "x86_64-linux",
    "builder": "/nix/store/qrxs7sabhqcr3j9ai0j0cp58zfnny0jz-coreutils-8.29/bin/true",
    "args": [],
    "env": {
      "builder": "/nix/store/qrxs7sabhqcr3j9ai0j0cp58zfnny0jz-coreutils-8.29/bin/true",
      "name": "myname",
      "out": "/nix/store/ly2k1vswbfmswr33hw0kf0ccilrpisnk-myname",
      "system": "x86_64-linux"
    }
  }
}
```

Aha! Nix added a dependency to our myname.drv, it's the coreutils.drv. Before doing our build, Nix should build the coreutils.drv. But since coreutils is already in our nix store, no build is needed, it's already there with out path `/nix/store/qrxs7sabhqcr3j9ai0j0cp58zfnny0jz-coreutils-8.29`.

## When is the derivation built

Nix does not build derivations **during evaluation** of Nix expressions. In fact, that's why we have to do ":b drv" in `nix repl`, or use nix-store -r in the first place.

An important separation is made in Nix:

- **Instantiate/Evaluation time**: the Nix expression is parsed, interpreted and finally returns a derivation set. During evaluation, you can refer to other derivations because Nix will create .drv files and we will know out paths beforehand. This is achieved with [nix-instantiate](https://nix.dev/manual/nix/stable/command-ref/nix-instantiate).

- **Realise/Build time**: the .drv from the derivation set is built, first building .drv inputs (build dependencies). This is achieved with [nix-store -r](https://nix.dev/manual/nix/stable/command-ref/nix-store/realise).

Think of it as of compile time and link time like with C/C++ projects. You first compile all source files to object files. Then link object files in a single executable.

In Nix, first the Nix expression (usually in a .nix file) is compiled to .drv, then each .drv is built and the product is installed in the relative out paths.

## Conclusion

Is it that complicated to create a package for Nix? No, it's not.

We're walking through the fundamentals of Nix derivations, to understand how they work, how they are represented. Packaging in Nix is certainly easier than that, but we're not there yet in this post. More Nix pills are needed.

With the derivation function we provide a set of information on how to build a package, and we get back the information about where the package was built. Nix converts a set to a string when there's an `outPath`; that's very convenient. With that, it's easy to refer to other derivations.

When Nix builds a derivation, it first creates a .drv file from a derivation expression, and uses it to build the output. It does so recursively for all the dependencies (inputs). It "executes" the .drv files like a machine. Not much magic after all.

## Next pill

...we will finally write our first **working** derivation. Yes, this post is about "our first derivation", but I never said it was a working one ;)
