let
  pkgs = import <nixpkgs> {};
  mkDerivation = import ./autotools.nix pkgs;
in with pkgs; {
  hello = import ./hello.nix { inherit mkDerivation; };
  graphviz = import ./graphviz.nix { inherit mkDerivation lib gd pkg-config; };
  graphvizCore = import ./graphviz.nix {
    inherit mkDerivation lib gd pkg-config;
    gdSupport = false;
  };
}
