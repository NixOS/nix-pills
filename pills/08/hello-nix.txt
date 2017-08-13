with (import <nixpkgs> {});
derivation {
  name = "hello";
  builder = "${bash}/bin/bash";
  args = [ ./hello_builder.sh ];
  inherit gnutar gzip gnumake gcc binutils coreutils gawk gnused gnugrep;
  src = ./hello-2.9.tar.gz;
  system = builtins.currentSystem;
}
