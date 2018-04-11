let

  nixpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6675f0a52c0962042a1000c7f20e887d0d26ae25.tar.gz";
  }) {};

  inherit (nixpkgs) stdenv fetchurl;

  actualHello = stdenv.mkDerivation {
    name = "hello-2.3";

    src = fetchurl {
      url = mirror://gnu/hello/hello-2.3.tar.bz2;
      sha256 = "0c7vijq8y68bpr7g6dh1gny0bff8qq81vnp4ch8pjzvg56wb3js1";
    };
  };

  intermediary = stdenv.mkDerivation {
    name = "middle-man";

    propagatedBuildInputs = [ actualHello ];

    installPhase = ''
      mkdir -p "$out"
    '';
  };

  wrappedHello = stdenv.mkDerivation {
    name = "hello-wrapper";

    buildInputs = [ intermediary ];

    installPhase = ''
      mkdir -p "$out/bin"
      echo "#! ${stdenv.shell}" >> "$out/bin/hello"
      echo "exec $(command -v hello)" >> "$out/bin/hello"
    '';
  };

in wrappedHello
