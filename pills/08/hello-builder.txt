export PATH="$gnutar/bin:$gcc/bin:$gnumake/bin:$coreutils/bin:$gawk/bin:$gzip/bin:$gnugrep/bin:$gnused/bin:$binutils/bin"
tar -xzf $src
cd hello-2.10
./configure --prefix=$out
make
make install
