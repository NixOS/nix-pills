findInputs() {
    local pkg=$1

    ## Don't need to repeat already processed package
    case $pkgs in
        *\ $pkg\ *)
            return 0
            ;;
    esac

    pkgs="$pkgs $pkg "

    ## More goes here in reality that we can ignore for now.
}
