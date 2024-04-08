# Override Design Pattern

Welcome to the 14th Nix pill. In the previous [13th](13-callpackage-design-pattern.md) pill, we introduced the `callPackage` pattern and used it to simplify the composition of software in a repository.

The next design pattern is less necessary, but is useful in many cases and is a good exercise to learn more about Nix.

## About composability

Functional languages are known for being able to compose functions. In particular, these languages gain expressivity from functions that manipulate an original value into a new value having the same structure. This allows us to compose multiple functions to perform the desired modifications.

In Nix, we mostly talk about **functions** that accept inputs in order to return **derivations**. In our world, we want utility functions that are able to manipulate those structures. These utilities add some useful properties to the original value, and we'd like to be able to apply more utilities on top of the result.

For example, let's say we have an initial derivation `drv` and we want to transform it into a `drv` with debugging information and custom patches:

```nix
debugVersion (applyPatches [ ./patch1.patch ./patch2.patch ] drv)
```

The final result should be the original derivation with some changes. This is both interesting and very different from other packaging approaches, which is a consequence of using a functional language to describe packages.

Designing such utilities is not trivial in a functional language without static typing, because understanding what can or cannot be composed is difficult. But we try to do our best.

## The override pattern

In [pill 12](12-inputs-design-pattern.md) we introduced the inputs design pattern. We do not return a derivation picking dependencies directly from the repository; rather we declare the inputs and let the callers pass the necessary arguments.

In our repository we have a set of attributes that import the expressions of the packages and pass these arguments, getting back a derivation. Let's take for example the `graphviz` attribute:

```nix
graphviz = import ./graphviz.nix { inherit mkDerivation gd fontconfig libjpeg bzip2; };
```

If we wanted to produce a derivation of `graphviz` with a customized `gd` version, we would have to repeat most of the above plus specifying an alternative `gd`:

```nix
{
  mygraphviz = import ./graphviz.nix {
    inherit
      mkDerivation
      fontconfig
      libjpeg
      bzip2
      ;
    gd = customgd;
  };
}
```

That's hard to maintain. Using `callPackage` would be easier:

```nix
mygraphviz = callPackage ./graphviz.nix { gd = customgd; };
```

But we may still be diverging from the original graphviz in the repository.

We would like to avoid specifying the nix expression again. Instead, we would like to reuse the original `graphviz` attribute in the repository and add our overrides like so:

```nix
mygraphviz = graphviz.override { gd = customgd; };
```

The difference is obvious, as well as the advantages of this approach.

Note: that `.override` is not a "method" in the OO sense as you may think. Nix is a functional language. The`.override` is simply an attribute of a set.

## The override implementation

Recall that the `graphviz` attribute in the repository is the derivation returned by the function imported from `graphviz.nix`. We would like to add a further attribute named "`override`" to the returned set.

Let's start by first creating a function "`makeOverridable`". This function will take two arguments: a function (that must return a set) and the set of original arguments to be passed to the function.

We will put this function in a `lib.nix`:

```nix
{
  makeOverridable =
    f: origArgs:
    let
      origRes = f origArgs;
    in
    origRes // { override = newArgs: f (origArgs // newArgs); };
}
```

`makeOverridable` takes a function and a set of original arguments. It returns the original returned set, plus a new `override` attribute.

This `override` attribute is a function taking a set of new arguments, and returns the result of the original function called with the original arguments unified with the new arguments. This is admittedly somewhat confusing, but the examples below should make it clear.

Let's try it with `nix repl`:

```console
$ nix repl
nix-repl> :l lib.nix
Added 1 variables.
nix-repl> f = { a, b }: { result = a+b; }
nix-repl> f { a = 3; b = 5; }
{ result = 8; }
nix-repl> res = makeOverridable f { a = 3; b = 5; }
nix-repl> res
{ override = «lambda»; result = 8; }
nix-repl> res.override { a = 10; }
{ result = 15; }
```

Note that, as we specified above, the function `f` does not return the plain sum. Instead, it returns a set with the sum bound to the name `result`.

The variable `res` contains the result of the function call without any override. It's easy to see in the definition of `makeOverridable`. In addition, you can see that the new `override` attribute is a function.

Calling `res.override` with a set will invoke the original function with the overrides, as expected.

This is a good start, but we can't override again! This is because the returned set (with `result = 15`) does not have an `override` attribute of its own. This is bad; it breaks further composition.

The solution is simple: the `.override` function should make the result overridable again:

```nix
rec {
  makeOverridable =
    f: origArgs:
    let
      origRes = f origArgs;
    in
    origRes // { override = newArgs: makeOverridable f (origArgs // newArgs); };
}
```

Please note the `rec` keyword. It's necessary so that we can refer to `makeOverridable` from `makeOverridable` itself.

Now let's try overriding twice:

```console
nix-repl> :l lib.nix
Added 1 variables.
nix-repl> f = { a, b }: { result = a+b; }
nix-repl> res = makeOverridable f { a = 3; b = 5; }
nix-repl> res2 = res.override { a = 10; }
nix-repl> res2
{ override = «lambda»; result = 15; }
nix-repl> res2.override { b = 20; }
{ override = «lambda»; result = 30; }
```

Success! The result is 30 (as expected) because `a` is overridden to 10 in the first override, and `b` is overridden to 20 in the second.

Now it would be nice if `callPackage` made our derivations overridable. This is an exercise for the reader.

## Conclusion

The "`override`" pattern simplifies the way we customize packages starting from an existing set of packages. This opens a world of possibilities for using a central repository like `nixpkgs` and defining overrides on our local machine without modifying the original package.

We can dream of a custom, isolated `nix-shell` environment for testing `graphviz` with a custom `gd`:

```nix
debugVersion (graphviz.override { gd = customgd; })
```

Once a new version of the overridden package comes out in the repository, the customized package will make use of it automatically.

The key in Nix is to find powerful yet simple abstractions in order to let the user customize their environment with highest consistency and lowest maintenance time, by using predefined composable components.

## Next pill

In the next pill, we will talk about Nix search paths. By "search path", we mean a place in the file system where Nix looks for expressions. This answers the question of where `<nixpkgs>` comes from.
