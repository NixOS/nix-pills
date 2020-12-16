{
  packageOverrides = pkgs: {
    graphviz = pkgs.graphviz.override { xorg = null; };
  };
}
