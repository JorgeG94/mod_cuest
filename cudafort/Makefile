# Makefile for cudafort -- Fortran bindings to the CUDA APIs.
#
#   make            # build the modules (cuda_runtime, cuda_driver, cuda_helpers)
#   make test       # build and run the self-test (works on any CUDA GPU)
#   make regen      # regenerate the bindings from $CUDA_HOME headers
#   make clean
#
# Override on the command line, e.g.:
#   make FC=nvfortran
#   make CUDA_HOME=/apps/cuda/12.9.0

CUDA_HOME   ?= /usr/local/cuda
FC          ?= gfortran
FFLAGS      ?= -O2 -std=f2008 -Wall
CUDA_LIBDIR ?= $(CUDA_HOME)/lib64
CUDA_LIBS   := -L$(CUDA_LIBDIR) -lcudart -Wl,-rpath,$(CUDA_LIBDIR)

# The driver API lives in libcuda.so, which on a login node without a driver
# is only present as a stub. Link it only when something needs it.
CUDA_DRV_LIBS := -L$(CUDA_LIBDIR)/stubs -lcuda

OBJS := cuda_runtime.o cuda_driver.o cuda_helpers.o

.PHONY: all test regen clean

all: $(OBJS)

cuda_runtime.o cuda_runtime.mod: cuda_runtime.f90
	$(FC) $(FFLAGS) -c cuda_runtime.f90

cuda_driver.o cuda_driver.mod: cuda_driver.f90
	$(FC) $(FFLAGS) -c cuda_driver.f90

cuda_helpers.o cuda_helpers.mod: cuda_helpers.f90 cuda_runtime.mod
	$(FC) $(FFLAGS) -c cuda_helpers.f90

test_cuda: test_cuda.f90 cuda_runtime.o cuda_helpers.o
	$(FC) $(FFLAGS) test_cuda.f90 cuda_runtime.o cuda_helpers.o -o $@ $(CUDA_LIBS)

test: test_cuda
	./test_cuda

regen:
	python3 generate_cuda_fortran.py --cuda $(CUDA_HOME)

clean:
	rm -f *.o *.mod test_cuda
