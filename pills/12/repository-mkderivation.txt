let
  pkgs = import <nixpkgs> {};
  mkDerivation = import ./autotools.nix pkgs;
in with pkgs; {
  hello = import ./hello.nix { inherit mkDerivation; }; 
  graphviz = import ./graphviz.nix { inherit mkDerivation gd fontconfig libjpeg bzip2; };
  graphvizCore = import ./graphviz.nix {
    inherit mkDerivation gd fontconfig libjpeg bzip2;
    gdSupport = false;
  };
}
