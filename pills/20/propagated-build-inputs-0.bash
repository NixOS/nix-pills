fixupPhase() {

    ## Elided

    if test -n "$propagatedBuildInputs"; then
        ensureDir "$out/nix-support"
        echo "$propagatedBuildInputs" > "$out/nix-support/propagated-build-inputs"
    fi

    ## Elided

}
