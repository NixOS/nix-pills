pkgs=""
for i in $buildInputs $propagatedBuildInputs; do
    findInputs $i
done
