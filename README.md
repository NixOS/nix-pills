# Nix Pills

Available online as a [multi-page HTML](https://nixos.org/guides/nix-pills/) or an [e-book in EPUB format](https://nixos.org/guides/nix-pills/nix-pills.epub).

You can also build them locally:

    nix-build release.nix -A html-split && firefox result/share/doc/nix-pills/index.html

Similarly, for an [EPUB](https://www.w3.org/publishing/epub32/) version, run:

    nix-build release.nix -A epub && foliate result/share/doc/nix-pills/nix-pills.epub
