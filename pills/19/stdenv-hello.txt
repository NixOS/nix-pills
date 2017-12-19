with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "hello";
  src = ./hello-2.10.tar.gz;
}
