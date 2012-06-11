#! /bin/sh

dmd -oftest test.d libconfig.d && ./test -L-lconfig
rm -f test
