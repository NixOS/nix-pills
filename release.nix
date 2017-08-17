let
  pkgs = import <nixpkgs> { };
in rec {
  html-split = import ./default.nix { inherit pkgs; };

  release = pkgs.releaseTools.aggregate
    { name = "nix-pills-release";
      constituents =
        [ html-split
        ];
      meta.description = "All build outputs";
    };
  };

}
