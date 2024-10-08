# Nix Store Paths

Welcome to the 18th Nix pill. In the previous [17th](17-nixpkgs-overriding-packages.md) pill we have scratched the surface of the `nixpkgs` repository structure. It is a set of packages, and it's possible to override such packages so that all other packages will use the overrides.

Before reading existing derivations, I'd like to talk about store paths and how they are computed. In particular we are interested in fixed store paths that depend on an integrity hash (e.g. a sha256), which is usually applied to source tarballs.

The way store paths are computed is a little contrived, mostly due to historical reasons. Our reference will be the [Nix source code](https://github.com/NixOS/nix/blob/07f992a74b64f4376d5b415d0042babc924772f3/src/libstore/store-api.cc#L197).

## Source paths

Let's start simple. You know nix allows relative paths to be used, such that the file or directory is stored in the nix store, that is `./myfile` gets stored into `/nix/store/.......` We want to understand how is the store path generated for such a file:

```console
$ echo mycontent > myfile
```

I remind you, the simplest derivation you can write has a `name`, a `builder` and the `system`:

```console
$ nix repl
nix-repl> derivation { system = "x86_64-linux"; builder = ./myfile; name = "foo"; }
«derivation /nix/store/y4h73bmrc9ii5bxg6i7ck6hsf5gqv8ck-foo.drv»
```

Now inspect the .drv to see where is `./myfile` being stored:

```console
$ nix derivation show /nix/store/y4h73bmrc9ii5bxg6i7ck6hsf5gqv8ck-foo.drv
{
  "/nix/store/y4h73bmrc9ii5bxg6i7ck6hsf5gqv8ck-foo.drv": {
    "outputs": {
      "out": {
        "path": "/nix/store/hs0yi5n5nw6micqhy8l1igkbhqdkzqa1-foo"
      }
    },
    "inputSrcs": [
      "/nix/store/xv2iccirbrvklck36f1g7vldn5v58vck-myfile"
    ],
    "inputDrvs": {},
    "platform": "x86_64-linux",
    "builder": "/nix/store/xv2iccirbrvklck36f1g7vldn5v58vck-myfile",
    "args": [],
    "env": {
      "builder": "/nix/store/xv2iccirbrvklck36f1g7vldn5v58vck-myfile",
      "name": "foo",
      "out": "/nix/store/hs0yi5n5nw6micqhy8l1igkbhqdkzqa1-foo",
      "system": "x86_64-linux"
    }
  }
}
```

Great, how did nix decide to use `xv2iccirbrvklck36f1g7vldn5v58vck` ? Keep looking at the nix comments.

**Note:** doing `nix-store --add myfile` will store the file in the same store path.

### Step 1, compute the hash of the file

The comments tell us to first compute the sha256 of the NAR serialization of the file. Can be done in two ways:

```console
$ nix-hash --type sha256 myfile
2bfef67de873c54551d884fdab3055d84d573e654efa79db3c0d7b98883f9ee3
```

Or:

```console
$ nix-store --dump myfile|sha256sum
2bfef67de873c54551d884fdab3055d84d573e654efa79db3c0d7b98883f9ee3
```

In general, Nix understands two contents: flat for regular files, or recursive for NAR serializations which can be anything.

### Step 2, build the string description

Then nix uses a special string which includes the hash, the path type and the file name. We store this in another file:

```console
$ echo -n "source:sha256:2bfef67de873c54551d884fdab3055d84d573e654efa79db3c0d7b98883f9ee3:/nix/store:myfile" > myfile.str
```

### Step 3, compute the final hash

Finally the comments tell us to compute the base-32 representation of the first 160 bits (truncation) of a sha256 of the above string:

```console
$ nix-hash --type sha256 --truncate --base32 --flat myfile.str
xv2iccirbrvklck36f1g7vldn5v58vck
```

## Output paths

Output paths are usually generated for derivations. We use the above example because it's simple. Even if we didn't build the derivation, nix knows the out path `hs0yi5n5nw6micqhy8l1igkbhqdkzqa1`. This is because the out path only depends on inputs.

It's computed in a similar way to source paths, except that the .drv is hashed and the type of derivation is `output:out`. In case of multiple outputs, we may have different `output:<id>`.

At the time nix computes the out path, the .drv contains an empty string for each out path. So what we do is getting our .drv and replacing the out path with an empty string:

```console
$ cp -f /nix/store/y4h73bmrc9ii5bxg6i7ck6hsf5gqv8ck-foo.drv myout.drv
$ sed -i 's,/nix/store/hs0yi5n5nw6micqhy8l1igkbhqdkzqa1-foo,,g' myout.drv
```

The `myout.drv` is the .drv state in which nix is when computing the out path for our derivation:

```console
$ sha256sum myout.drv
1bdc41b9649a0d59f270a92d69ce6b5af0bc82b46cb9d9441ebc6620665f40b5  myout.drv
$ echo -n "output:out:sha256:1bdc41b9649a0d59f270a92d69ce6b5af0bc82b46cb9d9441ebc6620665f40b5:/nix/store:foo" > myout.str
$ nix-hash --type sha256 --truncate --base32 --flat myout.str
hs0yi5n5nw6micqhy8l1igkbhqdkzqa1
```

Then nix puts that out path in the .drv, and that's it.

In case the .drv has input derivations, that is it references other .drv, then such .drv paths are replaced by this same algorithm which returns a hash.

In other words, you get a final .drv where every other .drv path is replaced by its hash.

## Fixed-output paths

Finally, the other most used kind of path is when we know beforehand an integrity hash of a file. This is usual for tarballs.

A derivation can take three special attributes: `outputHashMode`, `outputHash` and `outputHashAlgo` which are well documented in the [nix manual](https://nix.dev/manual/nix/stable/language/advanced-attributes).

The builder must create the out path and make sure its hash is the same as the one declared with `outputHash`.

Let's say our builder should create a file whose contents is `mycontent`:

```console
$ echo mycontent > myfile
$ sha256sum myfile
f3f3c4763037e059b4d834eaf68595bbc02ba19f6d2a500dce06d124e2cd99bb  myfile
nix-repl> derivation { name = "bar"; system = "x86_64-linux"; builder = "none"; outputHashMode = "flat"; outputHashAlgo = "sha256"; outputHash = "f3f3c4763037e059b4d834eaf68595bbc02ba19f6d2a500dce06d124e2cd99bb"; }
«derivation /nix/store/ymsf5zcqr9wlkkqdjwhqllgwa97rff5i-bar.drv»
```

Inspect the .drv and see that it also stored the fact that it's a fixed-output derivation with sha256 algorithm, compared to the previous examples:

```console
$ nix derivation show /nix/store/ymsf5zcqr9wlkkqdjwhqllgwa97rff5i-bar.drv
{
  "/nix/store/ymsf5zcqr9wlkkqdjwhqllgwa97rff5i-bar.drv": {
    "outputs": {
      "out": {
        "path": "/nix/store/a00d5f71k0vp5a6klkls0mvr1f7sx6ch-bar",
        "hashAlgo": "sha256",
        "hash": "f3f3c4763037e059b4d834eaf68595bbc02ba19f6d2a500dce06d124e2cd99bb"
      }
    },
[...]
}
```

It doesn't matter which input derivations are being used, the final out path must only depend on the declared hash.

What nix does is to create an intermediate string representation of the fixed-output content:

```console
$ echo -n "fixed:out:sha256:f3f3c4763037e059b4d834eaf68595bbc02ba19f6d2a500dce06d124e2cd99bb:" > mycontent.str
$ sha256sum mycontent.str
423e6fdef56d53251c5939359c375bf21ea07aaa8d89ca5798fb374dbcfd7639  myfile.str
```

Then proceed as it was a normal derivation output path:

```console
$ echo -n "output:out:sha256:423e6fdef56d53251c5939359c375bf21ea07aaa8d89ca5798fb374dbcfd7639:/nix/store:bar" > myfile.str
$ nix-hash --type sha256 --truncate --base32 --flat myfile.str
a00d5f71k0vp5a6klkls0mvr1f7sx6ch
```

Hence, the store path only depends on the declared fixed-output hash.

## Conclusion

There are other types of store paths, but you get the idea. Nix first hashes the contents, then creates a string description, and the final store path is the hash of this string.

Also we've introduced some fundamentals, in particular the fact that Nix knows beforehand the out path of a derivation since it only depends on the inputs. We've also introduced fixed-output derivations which are especially used by the nixpkgs repository for downloading and verifying source tarballs.

## Next pill

...we will introduce `stdenv`. In the previous pills we rolled our own `mkDerivation` convenience function for wrapping the builtin derivation, but the `nixpkgs` repository also has its own convenience functions for dealing with `autotools` projects and other build systems.
