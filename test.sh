#! /bin/sh

dmd -g -gc -gs -oftest test.d libconfig.d deimos/libconfig.d -L-lconfig && ./test
