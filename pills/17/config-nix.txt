{
  packageOverrides = pkgs: {
    graphviz = pkgs.graphviz.override { xlibs = null; };
  };
}
