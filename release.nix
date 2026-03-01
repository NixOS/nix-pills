{ nix-pills ? { outPath = ./.; }
, nixpkgs ? { outPath = <nixpkgs>; }
, officialRelease ? false
}:

let
  pkgs = import <nixpkgs> { };

  pills = import ./default.nix {
    inherit pkgs;
  };
in rec {
  inherit (pills) html-split epub;
  release = pkgs.releaseTools.aggregate
    { name = "nix-pills-release";
      constituents =
        [
          html-split
          epub
        ];
      meta.description = "All build outputs";
    };
}
