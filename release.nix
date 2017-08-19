{ nix-pills ? { outPath = ./.; revCount = 1234; shortRev = "abcdef"; }
, nixpkgs ? { outPath = <nixpkgs>; revCount = 1234; shortRev = "abcdef"; }
, officialRelease ? false
}:

let
  pkgs = import <nixpkgs> { };
in rec {
  html-split = import ./default.nix {
    inherit pkgs;

    inherit (nix-pills) revCount shortRev;
  };

  release = pkgs.releaseTools.aggregate
    { name = "nix-pills-release";
      constituents =
        [ html-split
        ];
      meta.description = "All build outputs";
    };
}
