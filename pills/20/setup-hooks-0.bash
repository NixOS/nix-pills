findInputs() {
    local pkg=$1

    ## More goes here in reality that we can ignore for now.

    if test -f $pkg/nix-support/setup-hook; then
        source $pkg/nix-support/setup-hook
    fi

    ## More goes here in reality that we can ignore for now.

}
