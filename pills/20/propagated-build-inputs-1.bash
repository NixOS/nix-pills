findInputs() {
    local pkg=$1

    ## More goes here in reality that we can ignore for now.

    if test -f $pkg/nix-support/propagated-build-inputs; then
        for i in $(cat $pkg/nix-support/propagated-build-inputs); do
            findInputs $i
        done
    fi
}
