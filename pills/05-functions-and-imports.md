# Functions and Imports

Welcome to the fifth Nix pill. In the previous [fourth pill](04-basics-of-language.md) we touched the Nix language for a moment. We introduced basic types and values of the Nix language, and basic expressions such as `if`, `with` and `let`. I invite you to re-read about these expressions and play with them in the repl.

Functions help to build reusable components in a big repository like [nixpkgs](https://github.com/NixOS/nixpkgs/). The Nix manual has a [great explanation of functions](https://nix.dev/manual/nix/stable/language/constructs#functions). Let's go: pill on one hand, Nix manual on the other hand.

I remind you how to enter the Nix environment: `source ~/.nix-profile/etc/profile.d/nix.sh`

## Nameless and single parameter

Functions are anonymous (lambdas), and only have a single parameter. The syntax is extremely simple. Type the parameter name, then "`:`", then the body of the function.

```console
nix-repl> x: x*2
«lambda»
```

So here we defined a function that takes a parameter `x`, and returns `x*2`. The problem is that we cannot use it in any way, because it's unnamed... joke!

We can store functions in variables.

```console
nix-repl> double = x: x*2
nix-repl> double
«lambda»
nix-repl> double 3
6
```

As usual, please ignore the special syntax for assignments inside `nix repl`. So, we defined a function `x: x*2` that takes one parameter `x`, and returns `x*2`. This function is then assigned to the variable `double`. Finally we did our first function call: `double 3`.

Big note: it's not like many other programming languages where you write `double(3)`. It really is `double 3`.

In summary: to call a function, name the variable, then space, then the argument. Nothing else to say, it's as easy as that.

## More than one parameter

How do we create a function that accepts more than one parameter? For people not used to functional programming, this may take a while to grasp. Let's do it step by step.

```console
nix-repl> mul = a: (b: a*b)
nix-repl> mul
«lambda»
nix-repl> mul 3
«lambda»
nix-repl> (mul 3) 4
12
```

We defined a function that takes the parameter `a`, the body returns another function. This other function takes a parameter `b` and returns `a*b`. Therefore, calling `mul 3` returns this kind of function: `b: 3*b`. In turn, we call the returned function with `4`, and get the expected result.

You don't have to use parentheses at all, Nix has sane priorities when parsing the code:

```console
nix-repl> mul = a: b: a*b
nix-repl> mul
«lambda»
nix-repl> mul 3
«lambda»
nix-repl> mul 3 4
12
nix-repl> mul (6+7) (8+9)
221
```

Much more readable, you don't even notice that functions only receive one argument. Since the argument is separated by a space, to pass more complex expressions you need parentheses. In other common languages you would write `mul(6+7, 8+9)`.

Given that functions have only one parameter, it is straightforward to use **partial application**:

```console
nix-repl> foo = mul 3
nix-repl> foo 4
12
nix-repl> foo 5
15
```

We stored the function returned by `mul 3` into a variable foo, then reused it.

## Argument set

Now this is a very cool feature of Nix. It is possible to pattern match over a set in the parameter. We write an alternative version of `mul = a: b: a*b` first by using a set as argument, then using pattern matching.

```console
nix-repl> mul = s: s.a*s.b
nix-repl> mul { a = 3; b = 4; }
12
nix-repl> mul = { a, b }: a*b
nix-repl> mul { a = 3; b = 4; }
12
```

In the first case we defined a function that accepts a single parameter. We then access attributes `a` and `b` from the given set. Note how the parentheses-less syntax for function calls is very elegant in this case, instead of doing `mul({ a=3; b=4; })` in other languages.

In the second case we defined an argument set. It's like defining a set, except without values. We require that the passed set contains the keys `a` and `b`. Then we can use those `a` and `b` in the function body directly.

```console
nix-repl> mul = { a, b }: a*b
nix-repl> mul { a = 3; b = 4; c = 6; }
error: anonymous function at (string):1:2 called with unexpected argument `c', at (string):1:1
nix-repl> mul { a = 3; }
error: anonymous function at (string):1:2 called without required argument `b', at (string):1:1
```

Only a set with exactly the attributes required by the function is accepted, nothing more, nothing less.

## Default and variadic attributes

It is possible to specify **default values** of attributes in the argument set:

```console
nix-repl> mul = { a, b ? 2 }: a*b
nix-repl> mul { a = 3; }
6
nix-repl> mul { a = 3; b = 4; }
12
```

Also you can allow passing more attributes (**variadic**) than the expected ones:

```console
nix-repl> mul = { a, b, ... }: a*b
nix-repl> mul { a = 3; b = 4; c = 2; }
```

However, in the function body you cannot access the "c" attribute. The solution is to give a name to the given set with the **@-pattern**:

```console
nix-repl> mul = s@{ a, b, ... }: a*b*s.c
nix-repl> mul { a = 3; b = 4; c = 2; }
24
```

That's it, you give a name to the whole parameter with name@ before the set pattern.

Advantages of using argument sets:

- Named unordered arguments: you don't have to remember the order of the arguments.

- You can pass sets, that adds a whole new layer of flexibility and convenience.

Disadvantages:

- Partial application does not work with argument sets. You have to specify the whole attribute set, not part of it.

You may find similarities with [Python \*\*kwargs](https://docs.python.org/3/faq/programming.html#how-can-i-pass-optional-or-keyword-parameters-from-one-function-to-another).

## Imports

The `import` function is built-in and provides a way to parse a `.nix` file. The natural approach is to define each component in a `.nix` file, then compose by importing these files.

Let's start with the bare metal.

`a.nix`:

```nix
3
```

`b.nix`:

```nix
4
```

`mul.nix`:

```nix
a: b: a*b
```

```console
nix-repl> a = import ./a.nix
nix-repl> b = import ./b.nix
nix-repl> mul = import ./mul.nix
nix-repl> mul a b
12
```

Yes it's really that simple. You import a file, and it gets parsed as an expression. Note that the scope of the imported file does not inherit the scope of the importer.

`test.nix`:

```nix
x
```

```console
nix-repl> let x = 5; in import ./test.nix
error: undefined variable `x' at /home/lethal/test.nix:1:1
```

So how do we pass information to the module? Use functions, like we did with `mul.nix`. A more complex example:

`test.nix`:

```nix
{ a, b ? 3, trueMsg ? "yes", falseMsg ? "no" }:
if a > b
  then builtins.trace trueMsg true
  else builtins.trace falseMsg false
```

```console
nix-repl> import ./test.nix { a = 5; trueMsg = "ok"; }
trace: ok
true
```

Explaining:

- In `test.nix` we return a function. It accepts a set, with default attributes `b`, `trueMsg` and `falseMsg`.

- `builtins.trace` is a [built-in function](https://nix.dev/manual/nix/stable/language/builtins) that takes two arguments. The first is the message to display, the second is the value to return. It's usually used for debugging purposes.

- Then we import `test.nix`, and call the function with that set.

So when is the message shown? Only when it needs to be evaluated.

## Next pill

...we will finally write our first derivation.
