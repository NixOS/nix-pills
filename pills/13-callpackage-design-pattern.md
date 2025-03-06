# Callpackage Design Pattern

Welcome to the 13th Nix pill. In the previous [12th pill](12-inputs-design-pattern.md), we introduced the first basic design pattern for organizing a repository of software. In addition, we packaged `graphviz` so that we had two packages to bundle into an example repository.

The next design pattern we will examine is called the `callPackage` pattern. This technique is extensively used in [nixpkgs](https://github.com/NixOS/nixpkgs), and it's the current de facto standard for importing packages in a repository. Its purpose is to reduce the duplication of identifiers between package derivation inputs and repository derivations.

## The callPackage convenience

In the previous pill, we demonstrated how the `inputs` pattern decouples packages from the repository. This allowed us to manually pass the inputs to the derivation; the derivation declares its inputs, and the caller passes the arguments.

However, as with usual programming languages, there is some duplication of work: we declare parameter names and then we pass arguments, typically with the same name. For example, if we define a package derivation using the `inputs` pattern such as:

```nix
{ input1, input2, ... }:
...
```

We would likely want to bundle that package derivation into a repository via an attribute set defined as something like:

```nix
rec {
  lib1 = import package1.nix { inherit input1 input2; };
  program2 = import package2.nix { inherit inputX inputY lib1; };
}
```

There are two things to note. First, that inputs often have the same name as attributes in the repository itself. Second, that (due to the `rec` keyword), the inputs to a package derivation may be other packages in the repository itself.

Rather than passing the inputs twice, we would prefer to pass those inputs from the repository automatically and allow for manually overriding defaults.

To achieve this, we will define a `callPackage` function with the following calling convention:

```nix
{
  lib1 = callPackage package1.nix { };
  program2 = callPackage package2.nix { someoverride = overriddenDerivation; };
}
```

We want `callPackage` to be a function of two arguments, with the following behavior:

- Import the given expression contained in the file of the first argument, and return a function. This function returns a package derivation that uses the inputs pattern.

- Determine the name of the arguments to the function (i.e., the names of the inputs to the package derivation).

- Pass default arguments from the repository set, and let us override those arguments if we wish to customize the package derivation.

## Implementing `callPackage`

In this section, we will build up the `callPackages` pattern from scratch. To start, we need a way to obtain the argument names of a function (in this case, the function that takes "inputs" and produces a package derivation) at runtime. This is because we want to automatically pass such arguments.

Nix provides a builtin function to do this:

```console
nix-repl> add = { a ? 3, b }: a+b
nix-repl> builtins.functionArgs add
{ a = true; b = false; }
```

In addition to returning the argument names, the attribute set returned by `functionArgs` indicates whether or not the argument has a default value. For our purposes, we are only interested in the argument names; we do not care about the default values right now.

The next step is to make `callPackage` automatically pass inputs to our package derivations based on the argument names we've just obtained with `functionArgs`.

To do this, we need two things:

- A package repository set containing package derivations that match the arguments names we've obtained

- A way to obtain an auto-populated attribute set combining the package repository and the return value of `functionArgs`.

The former is easy: we just have to set our package derivation's inputs to be package names in a repository, such as `nixpkgs`. For the latter, Nix provides another builtin function:

```console
nix-repl> values = { a = 3; b = 5; c = 10; }
nix-repl> builtins.intersectAttrs values (builtins.functionArgs add)
{ a = true; b = false; }
nix-repl> builtins.intersectAttrs (builtins.functionArgs add) values
{ a = 3; b = 5; }
```

The `intersectAttrs` returns an attribute set whose names are the intersection of both arguments' attribute names, with the attribute values taken from the second argument.

This is all we need to do: we have obtained the argument names from a function, and populated these with an existing set of attributes. This is our simple implementation of `callPackage`:

```console
nix-repl> callPackage = set: f: f (builtins.intersectAttrs (builtins.functionArgs f) set)
nix-repl> callPackage values add
8
nix-repl> with values; add { inherit a b; }
8
```

Let's dissect the above snippet:

- We define a `callPackage` variable which is a function.

- The first parameter to the `callPackage` function is a set of name-value pairs that may appear in the argument set of the function we wish to "autocall".

- The second parameter is the function to "autocall"

- We take the argument names of the function and intersect with the set of all values.

- Finally, we call the passed function `f` with the resulting intersection.

In the snippet above, we've also demonstrated that the `callPackage` call is equivalent to directly calling `add a b`.

We achieved most of what we wanted: to automatically call functions given a set of possible arguments. If an argument is not found within the set we used to call the function, then we receive an error (unless the function has variadic arguments denoted with `...`, as explained in the [5th pill](05-functions-and-imports.md)).

The last missing piece is allowing users to override some of the parameters. We may not want to always call functions with values taken from the big set. Thus, we add a third parameter which takes a set of overrides:

```console
nix-repl> callPackage = set: f: overrides: f ((builtins.intersectAttrs (builtins.functionArgs f) set) // overrides)
nix-repl> callPackage values add { }
8
nix-repl> callPackage values add { b = 12; }
15
```

Apart from the increasing number of parentheses, it should be clear that we simply take a set union between the default arguments and the overriding set.

## Using callPackage to simplify the repository

Given our `callPackages`, we can simplify the repository expression in `default.nix`:

```nix
let
  nixpkgs = import <nixpkgs> { };
  allPkgs = nixpkgs // pkgs;
  callPackage =
    path: overrides:
    let
      f = import path;
    in
    f ((builtins.intersectAttrs (builtins.functionArgs f) allPkgs) // overrides);
  pkgs = with nixpkgs; {
    mkDerivation = import ./autotools.nix nixpkgs;
    hello = callPackage ./hello.nix { };
    graphviz = callPackage ./graphviz.nix { };
    graphvizCore = callPackage ./graphviz.nix { gdSupport = false; };
  };
in
pkgs
```

Let's examine this in detail:

- The expression above defines our own package repository, which we call `pkgs`, that contains `hello` along with our two variants of `graphviz`.

- In the `let` expression, we import `nixpkgs`. Note that previously, we referred to this import with the variable `pkgs`, but now that name is taken by the repository we are creating ourselves.

- We needed a way to pass `pkgs` to `callPackage` somehow. Instead of returning the set of packages directly from `default.nix`, we first assign it to a `let` variable and reuse it in `callPackage`.

- For convenience, in `callPackage` we first import the file instead of calling it directly. Otherwise we would have to write the `import` for each package.

- Since our expressions use packages from `nixpkgs`, in `callPackage` we use `allPkgs`, which is the union of `nixpkgs` and our packages.

- We moved `mkDerivation` into `pkgs` itself, so that it also gets passed automatically.

Note how easily we overrode arguments in the case of `graphviz` without `gd`. In addition, note how easy it was to merge two repositories: `nixpkgs` and our `pkgs`!

The reader should notice a magic thing happening. We're defining `pkgs` in terms of `callPackage`, and `callPackage` in terms of `pkgs`. That magic is possible thanks to lazy evaluation: `builtins.intersectAttrs` doesn't need to know the values in `allPkgs` in order to perform intersection, only the keys that do not require `callPackage` evaluation.

## Conclusion

The "`callPackage`" pattern has simplified our repository considerably. We were able to import packages that require named arguments and call them automatically, given the set of all packages sourced from `nixpkgs`.

We've also introduced some useful builtin functions that allows us to introspect Nix functions and manipulate attributes. These builtin functions are not usually used when packaging software, but rather act as tools for packaging. They are documented in the [Nix manual](https://nix.dev/manual/nix/stable/language/builtins).

Writing a repository in Nix is an evolution of writing convenient functions for combining the packages. This pill demonstrates how Nix can be a generic tool to build and deploy software, and how suitable it is to create software repositories with our own conventions.

## Next pill

In the next pill, we will talk about the "`override`" design pattern. The `graphvizCore` seems straightforward. It starts from `graphviz.nix` and builds it without `gd`. In the next pill, we will consider another point of view: starting from `pkgs.graphviz` and disabling `gd`?
