{ pkgs ? import <nixpkgs> {} }:

{
  html-split = pkgs.stdenvNoCC.mkDerivation {
    name = "nix-pills";
    src = ./.;

    nativeBuildInputs = with pkgs; [
      mdbook
      mdbook-linkcheck
    ];

    buildPhase = ''
      runHook preBuild

      # We can't check external links inside the sandbox, but it's good to check them outside the sandbox.
      substituteInPlace book.toml --replace-fail 'follow-web-links = true' 'follow-web-links = false'
      mdbook build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # The nix pills were originally built into this directory, and consumers of the nix pills expect to find it there. Do not change unless you also change other code that depends on this directory structure.
      dst=$out/share/doc/nix-pills
      mkdir -p "$dst"
      mv book/html/* "$dst"/

      mkdir -p "$out/nix-support"
      echo "nix-build out $out" >> "$out/nix-support/hydra-build-products"
      echo "doc nix-pills $dst" >> "$out/nix-support/hydra-build-products"

      runHook postInstall
    '';
  };

  epub = pkgs.stdenvNoCC.mkDerivation {
    name = "nix-pills-epub";
    src = ./.;

    nativeBuildInputs = with pkgs; [
      mdbook-epub
      unzip
      zip
    ];

    installCheckInputs = with pkgs; [
      epubcheck
    ];

    doInstallCheck = true;

    buildPhase = ''
      runHook preBuild

      mdbook-epub --standalone${pkgs.lib.optionalString (pkgs.mdbook-epub.version != "unstable-2022-12-25") " true"}

      # Work around bugs in mdbook-epub.
      mkdir nix-pills.epub-fix
      ( cd nix-pills.epub-fix
        unzip -q "../book/epub/Nix Pills.epub"
        # Fix invalid ids.
        sed -Ei 's/(id(ref)?=")([0-9])/\1p\3/g' OEBPS/content.opf
        sed -Ei 's/(id="|href="#)([0-9])/\1fn\2/g' OEBPS/20-basic-dependencies-and-hooks.html
        # Fix anchors.
        sed -Ei 's~(<h[1-6])(>.+) \{#([^\}]+)\}(</h[1-6]>)~\1 id="\3"\2\4~g' OEBPS/*.html
        # Fix broken links in body.
        sed -Ei 's/("[0-9a-z-]+\.)md(["#])/\1html\2/g' OEBPS/*.html
        zip -q "../book/epub/Nix Pills.epub" **/*
      )

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # The nix pills were originally built into this directory, and consumers of the nix pills expect to find it there. Do not change unless you also change other code that depends on this directory structure.
      dst=$out/share/doc/nix-pills
      mkdir -p "$dst"

      manual="$dst/nix-pills.epub"
      mv "book/epub/Nix Pills.epub" "$manual"

      mkdir -p "$out/nix-support"
      echo "nix-build out $out" >> "$out/nix-support/hydra-build-products"
      echo "doc-epub nix-pills $manual" >> "$out/nix-support/hydra-build-products"

      runHook postInstall
    '';

    installCheckPhase = ''
      runHook preInstallCheck

      epubcheck "$manual"

      runHook postInstallCheck
    '';
  };
}
