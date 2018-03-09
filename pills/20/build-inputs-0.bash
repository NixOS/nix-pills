pkgs=""
for i in $buildInputs; do
    findInputs $i
done
