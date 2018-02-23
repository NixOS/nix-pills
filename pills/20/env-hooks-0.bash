addToEnv() {
    local pkg=$1

    ## More goes here in reality that we can ignore for now.

    # Run the package-specific hooks set by the setup-hook scripts.
    for i in "${envHooks[@]}"; do
        $i $pkg
    done
}
