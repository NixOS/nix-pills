with (import <nixpkgs> {});
derivation {
  name = "hello";
  builder = "${bash}/bin/bash";
  args = [ ./hello_builder.sh ];
  inherit gnutar gzip gnumake gcc coreutils gawk gnused gnugrep;
  binutils = binutils-unwrapped;
  src = ./hello-2.10.tar.gz;
  system = builtins.currentSystem;
}
