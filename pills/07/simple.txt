let
  pkgs = import <nixpkgs> {};
in
  pkgs.stdenv.mkDerivation {
    name = "simple";
    builder = "${pkgs.bash}/bin/bash";
    args = [ ./simple_builder.sh ];
    gcc = pkgs.gcc;
    coreutils = pkgs.coreutils;
    src = ./simple.c;
    system = builtins.currentSystem;
}