# Makefile for the cuEST Fortran binding.
#
#   make            # compile the binding modules (cuest.mod, cuest_helpers.mod)
#   make example    # build the worked example (needs the cuEST + CUDA libs)
#   make regen      # regenerate cuest.f90 from ../include headers
#   make clean
#
# Override on the command line, e.g.:  make FC=nvfortran CUEST_ROOT=/opt/cuest

CUEST_ROOT ?= ..
FC          = gfortran          # override on the command line: make FC=nvfortran
FFLAGS     ?= -O2 -std=f2008
LIBDIR     := $(CUEST_ROOT)/lib

# Directory holding libcudart/libcublas/libcusolver. IMPORTANT: this must match
# the CUDA major version of your cuEST package AND be supported by your driver.
# A CUDA 13 runtime on a CUDA-12.x driver fails at cudaMalloc with
# cudaErrorInsufficientDriver (code 35). Point this at the SAME dir cuEST already
# loads its libcudart.so.<N> from:  ldd ./overlap_demo | grep cudart
# e.g. CUDA_LIBDIR=/home/jorge/install/x86/nvhpc/26.3/Linux_x86_64/26.3/cuda/12.8/lib64
CUDA_LIBDIR ?= /usr/local/cuda/lib64
CUDA_LIBS   := -L$(CUDA_LIBDIR) -lcudart -lcublas -lcusolver -lpthread -lm \
               -Wl,-rpath,$(CUDA_LIBDIR)

.PHONY: all lib example regen clean

all: lib

lib: cuest.o cuest_helpers.o

cuest.o cuest.mod: cuest.f90
	$(FC) $(FFLAGS) -c cuest.f90

cuest_helpers.o cuest_helpers.mod: cuest_helpers.f90 cuest.mod
	$(FC) $(FFLAGS) -c cuest_helpers.f90

example: overlap_demo

overlap_demo: example_overlap.f90 cuest.o cuest_helpers.o
	$(FC) $(FFLAGS) example_overlap.f90 cuest.o cuest_helpers.o -o $@ \
	  -L$(LIBDIR) -lcuest $(CUDA_LIBS) -Wl,-rpath,$(LIBDIR)

regen:
	python3 generate_cuest_fortran.py $(CUEST_ROOT)/include

clean:
	rm -f *.o *.mod overlap_demo
