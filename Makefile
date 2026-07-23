# Makefile for the cuEST Fortran binding.
#
#   make            # compile the binding modules (cuest.mod, cuest_helpers.mod)
#   make regen      # regenerate cuest.f90 from <cuest package>/include headers
#   make clean
#
# This builds the bindings ONLY. The worked examples live in fortran_examples/
# and are built with CMake:
#   cmake -S fortran_examples -B fortran_examples/build -DCUEST_ROOT=<pkg>
#
# `make` needs nothing but a Fortran compiler -- cuest.f90 is generated source.
# Only `make regen` needs the cuEST headers:
#
#   make regen CUEST_ROOT=/path/to/libcuest-...-archive
#
# This repository does NOT have to live inside the cuEST package. It is normally
# a sibling of it, and fortran_examples/ takes -DCUEST_ROOT=<pkg> explicitly.
# The only layout requirement is internal: fortran_examples/ expects cuest.f90,
# cuest_helpers.f90 and cudafort/ to sit one directory above it, i.e. here.
#
# Override on the command line, e.g.:  make FC=nvfortran

CUEST_ROOT ?= ..
FC          = gfortran          # override on the command line: make FC=nvfortran
FFLAGS     ?= -O2 -std=f2008

.PHONY: all lib regen clean

all: lib

lib: cuest.o cuest_helpers.o

cuest.o cuest.mod: cuest.f90
	$(FC) $(FFLAGS) -c cuest.f90

cuest_helpers.o cuest_helpers.mod: cuest_helpers.f90 cuest.mod
	$(FC) $(FFLAGS) -c cuest_helpers.f90

regen:
	@test -f "$(CUEST_ROOT)/include/cuest.h" || { \
	  echo "error: no cuEST headers at $(CUEST_ROOT)/include"; \
	  echo "       pass the package root explicitly, e.g."; \
	  echo "       make regen CUEST_ROOT=/path/to/libcuest-...-archive"; \
	  exit 1; }
	python3 generate_cuest_fortran.py $(CUEST_ROOT)/include

clean:
	rm -f *.o *.mod
