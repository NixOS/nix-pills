let

  nixpkgs = import <nixpkgs> {};

  inherit (nixpkgs) stdenv fetchurl which;

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

    unpackPhase = "true";

    installPhase = ''
      mkdir -p "$out"
    '';
  };

  wrappedHello = stdenv.mkDerivation {
    name = "hello-wrapper";

    buildInputs = [ intermediary which ];

    unpackPhase = "true";

    installPhase = ''
      mkdir -p "$out/bin"
      echo "#! ${stdenv.shell}" >> "$out/bin/hello"
      echo "exec $(which hello)" >> "$out/bin/hello"
      chmod 0755 "$out/bin/hello"
    '';
  };

in wrappedHello
