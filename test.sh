#! /bin/sh

dmd -oftest test.d libconfig.d deimos/libconfig.d -L-lconfig && ./test
rm -f test
