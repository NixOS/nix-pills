# Nix Pills

https://nixos.org/nixos/nix-pills/

You can also build them locally:

    nix-build release.nix -A html-split && firefox result/share/doc/nix-pills/index.html

Similarly, for an [EPUB](https://www.w3.org/publishing/epub32/) version, run:

    nix-build release.nix -A epub && foliate result/share/doc/nix-pills/nix-pills.epub

## Development

 - [List of DocBook Elements](https://tdg.docbook.org/tdg/5.2/part2.html)

Emacs config for a nice DocBook experience:

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
