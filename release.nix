{ nix-pills ? { outPath = ./.; revCount = 1234; shortRev = "abcdef"; }
, nixpkgs ? { outPath = <nixpkgs>; revCount = 1234; shortRev = "abcdef"; }
, officialRelease ? false
}:

let
  pkgs = import <nixpkgs> { };

  pills = import ./default.nix {
    inherit pkgs;

    inherit (nix-pills) revCount shortRev;
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
