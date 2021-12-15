# Nix Pills

https://nixos.org/nixos/nix-pills/

## Development

 - List of Elements: http://tdg.docbook.org/tdg/5.2/chunk-part-d6252e15351.html
 - Tracking Issue: https://github.com/NixOS/nixpkgs/issues/27908

When starting a new Pill, comment on the tracking issue which one
you're doing. If you need help, ask there. If you make progress but
don't finish in one go, make a PR anyway! I'm trying to not edit
things as I go, in order to not get bogged down.

How I've built and tested:

`nix-build release.nix -A html-split && firefox result/share/doc/nix-pills/index.html`

Emacs config for a nice docbook experience:

 ```nix
 let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) emacsPackagesNg docbook5 writeText;

  schemas = writeText "schemas.xml" ''
    <locatingRules xmlns="http://thaiopensource.com/ns/locating-rules/1.0">
      <documentElement localName="section" typeId="DocBook"/>
      <documentElement localName="chapter" typeId="DocBook"/>
      <documentElement localName="article" typeId="DocBook"/>
      <documentElement localName="book" typeId="DocBook"/>
      <typeId id="DocBook" uri="${docbook5}/xml/rng/docbook/docbookxi.rnc" />
    </locatingRules>
  '';

in emacsPackagesNg.emacsWithPackages (epkgs: [
  (emacsPackagesNg.trivialBuild {
    pname = "nix-docbook-mode";
    version = "1970-01-01";
    src = writeText "default.el" ''
      (eval-after-load 'rng-loc
        '(add-to-list 'rng-schema-locating-files "${schemas}"))
      (global-set-key (kbd "<C-return>") 'nxml-complete)
    '';
  })
])
```

Then you can use the keys:


 - `C-c C-b` to finish & close a tag
 - `C-c C-f` to close a tag
 - `C-return` to auto-complete a tag or attribute.
