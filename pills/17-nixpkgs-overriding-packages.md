# Nixpkgs Overriding Packages

Welcome to the 17th Nix pill. In the previous [16th](16-nixpkgs-parameters.md) pill we have started to dive into the [nixpkgs repository](http://github.com/NixOS/nixpkgs). `Nixpkgs` is a function, and we've looked at some parameters like `system` and `config`.

Today we'll talk about a special attribute: `config.packageOverrides`. Overriding packages in a set with fixed point can be considered another design pattern in nixpkgs.

## Overriding a package

Recall the override design pattern from the [nix pill 14](14-override-design-pattern.md). Instead of calling a function with parameters directly, we make the call (function + parameters) overridable.

We put the override function in the returned attribute set of the original function call.

Take for example `graphviz`. It has an input parameter `xorg`. If it's null, then `graphviz` will build without X support.

```console
$ nix repl
nix-repl> :l <nixpkgs>
Added 4360 variables.
nix-repl> :b graphviz.override { withXorg = false; }
```

This will build `graphviz` without X support, it's as simple as that.

However, let's say a package `P` depends on `graphviz`, how do we make `P` depend on the new `graphviz` without X support?

## In an imperative world...

...you could do something like this:

```nix
pkgs = import <nixpkgs> {};
pkgs.graphviz = pkgs.graphviz.override { withXorg = false; };
build(pkgs.P)
```

Given `pkgs.P` depends on `pkgs.graphviz`, it's easy to build `P` with the replaced `graphviz`. In a pure functional language it's not that easy because you can assign to variables only once.

## Fixed point

The fixed point with lazy evaluation is crippling but about necessary in a language like Nix. It lets us achieve something similar to what we'd do imperatively.

Follows the definition of fixed point in [nixpkgs](https://github.com/NixOS/nixpkgs/blob/f224a4f1b32b3e813783d22de54e231cd8ea2448/lib/fixed-points.nix#L19):

```nix
{
  # Take a function and evaluate it with its own returned value.
  fix =
    f:
    let
      result = f result;
    in
    result;
}
```

It's a function that accepts a function `f`, calls `f result` on the result just returned by `f result` and returns it. In other words it's `f(f(f(....`

At first sight, it's an infinite loop. With lazy evaluation it isn't, because the call is done only when needed.

```console
nix-repl> fix = f: let result = f result; in result
nix-repl> pkgs = self: { a = 3; b = 4; c = self.a+self.b; }
nix-repl> fix pkgs
{ a = 3; b = 4; c = 7; }
```

Without the `rec` keyword, we were able to refer to `a` and `b` of the same set.

- First `pkgs` gets called with an unevaluated thunk `(pkgs(pkgs(...)`

- To set the value of `c` then `self.a` and `self.b` are evaluated.

- The `pkgs` function gets called again to get the value of `a` and `b`.

The trick is that `c` is not needed to be evaluated in the inner call, thus it doesn't go in an infinite loop.

Won't go further with the explanation here. A good post about fixed point and Nix can be [found here](http://r6.ca/blog/20140422T142911Z.html).

### Overriding a set with fixed point

Given that `self.a` and `self.b` refer to the passed set and not to the literal set in the function, we're able to override both `a` and `b` and get a new value for `c`:

```console
nix-repl> overrides = { a = 1; b = 2; }
nix-repl> let newpkgs = pkgs (newpkgs // overrides); in newpkgs
{ a = 3; b = 4; c = 3; }
nix-repl> let newpkgs = pkgs (newpkgs // overrides); in newpkgs // overrides
{ a = 1; b = 2; c = 3; }
```

In the first case we computed pkgs with the overrides, in the second case we also included the overridden attributes in the result.

## Overriding nixpkgs packages

We've seen how to override attributes in a set such that they get recursively picked by dependent attributes. This approach can be used for derivations too, after all `nixpkgs` is a giant set of attributes that depend on each other.

To do this, `nixpkgs` offers `config.packageOverrides`. So `nixpkgs` returns a fixed point of the package set, and `packageOverrides` is used to inject the overrides.

Create a `config.nix` file like this somewhere:

```nix
{
    packageOverrides = pkgs: {
    graphviz = pkgs.graphviz.override {
      # disable xorg support
      withXorg = false;
    };
  };
}
```

Now we can build e.g. `asciidoc-full` and it will automatically use the overridden `graphviz`:

```console
nix-repl> pkgs = import <nixpkgs> { config = import ./config.nix; }
nix-repl> :b pkgs.asciidoc-full
```

Note how we pass the `config` with `packageOverrides` when importing `nixpkgs`. Then `pkgs.asciidoc-full` is a derivation that has `graphviz` input (`pkgs.asciidoc` is the lighter version and doesn't use `graphviz` at all).

Since there's no version of `asciidoc` with `graphviz` without X support in the binary cache, Nix will recompile the needed stuff for you.

## The \~/.config/nixpkgs/config.nix file

In the previous pill we already talked about this file. The above `config.nix` that we just wrote could be the content of `~/.config/nixpkgs/config.nix` (or the deprecated location `~/.nixpkgs/config.nix`).

Instead of passing it explicitly whenever we import `nixpkgs`, it will be automatically [imported by nixpkgs](https://github.com/NixOS/nixpkgs/blob/32c523914fdb8bf9cc7912b1eba023a8daaae2e8/pkgs/top-level/impure.nix#L28).

## Conclusion

We've learned about a new design pattern: using fixed point for overriding packages in a package set.

Whereas in an imperative setting, like with other package managers, a library is installed replacing the old version and applications will use it, in Nix it's not that straight and simple. But it's more precise.

Nix applications will depend on specific versions of libraries, hence the reason why we have to recompile `asciidoc` to use the new `graphviz` library.

The newly built `asciidoc` will depend on the new `graphviz`, and old `asciidoc` will keep using the old `graphviz` undisturbed.

## Next pill

...we will stop studying `nixpkgs` for a moment and talk about store paths. How does Nix compute the path in the store where to place the result of builds? How to add files to the store for which we have an integrity hash?
