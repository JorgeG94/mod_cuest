# Makefile for the Fortran ports of the cuEST C samples.
#
#   make                     # build all ported samples
#   make run-one_electron_integrals   # build and run it on the bundled data
#   make clean
#
# Requires a cuEST package for include/ and lib/:
#   make CUEST_PKG=/path/to/libcuest-linux-x86_64-<ver>_cuda12-archive
#
# NOTE: cuEST needs sm_80 or newer. These will build anywhere but only RUN on
# A100/H100 (Gadi: dgxa100 or gpuhopper, not gpuvolta).

CUEST_PKG   ?= ../../libcuest-linux-x86_64-0.2.0.4_cuda12-archive
CUDA_HOME   ?= /usr/local/cuda
FC          ?= gfortran
FFLAGS      ?= -O2 -std=f2008 -Wall
BUILD       := build

CUEST_LIBDIR := $(CUEST_PKG)/lib
CUDA_LIBDIR  ?= $(CUDA_HOME)/lib64
# Input data is bundled in data/ (see data/THIRD_PARTY_NOTICES.txt), so the
# examples run without a CUDALibrarySamples checkout. Point DATA at the
# upstream copy instead if you want to check them against it.
DATA         ?= data

LIBS := -L$(CUEST_LIBDIR) -lcuest \
        -L$(CUDA_LIBDIR) -lcudart -lcublas -lcusolver -lpthread -lm \
        -Wl,-rpath,$(CUEST_LIBDIR) -Wl,-rpath,$(CUDA_LIBDIR)

# Compilation order matters: modules must exist before their users.
SRC := ../cudafort/cuda_runtime.f90 \
       ../cudafort/cuda_helpers.f90 \
       ../cuest.f90 \
       ../cuest_helpers.f90 \
       common/cuest_sample_utils.f90 \
       common/xyz_parser.f90 \
       common/gbs_parser.f90 \
       common/ao_shells.f90
OBJ := $(addprefix $(BUILD)/,$(notdir $(SRC:.f90=.o)))

SAMPLES := one_electron_integrals
TESTS   := test_parsers

.PHONY: all clean test oracle compare $(addprefix run-,$(SAMPLES))

all: $(addprefix $(BUILD)/,$(SAMPLES)) $(addprefix $(BUILD)/,$(TESTS))

$(BUILD):
	@mkdir -p $(BUILD)

# One rule per source, built in list order via the explicit dependency chain
# below; -J puts the .mod files where later compiles will find them.
define COMPILE_RULE
$(BUILD)/$(notdir $(basename $(1))).o: $(1) | $(BUILD)
	$$(FC) $$(FFLAGS) -J$(BUILD) -c $$< -o $$@
endef
$(foreach s,$(SRC),$(eval $(call COMPILE_RULE,$(s))))

# Enforce the module dependency order.
$(BUILD)/cuda_helpers.o:       $(BUILD)/cuda_runtime.o
$(BUILD)/cuest_helpers.o:      $(BUILD)/cuest.o
$(BUILD)/cuest_sample_utils.o: $(BUILD)/cuest_helpers.o $(BUILD)/cuda_helpers.o
$(BUILD)/xyz_parser.o:         $(BUILD)/cuda_helpers.o
$(BUILD)/gbs_parser.o:         | $(BUILD)
$(BUILD)/ao_shells.o:          $(BUILD)/cuest_sample_utils.o \
                               $(BUILD)/xyz_parser.o $(BUILD)/gbs_parser.o

$(BUILD)/one_electron_integrals: 2_one_electron_integrals/one_electron_integrals.f90 $(OBJ)
	$(FC) $(FFLAGS) -J$(BUILD) -I$(BUILD) $< $(OBJ) -o $@ $(LIBS)

$(BUILD)/test_parsers: test_parsers.f90 $(OBJ)
	$(FC) $(FFLAGS) -J$(BUILD) -I$(BUILD) $< $(OBJ) -o $@ $(LIBS)

# Runs without creating a cuEST handle, so it works on any GPU (incl. Volta).
test: $(BUILD)/test_parsers
	$(BUILD)/test_parsers $(DATA)/geometry/h2o.xyz $(DATA)/basis_set/def2-svp.gbs

run-one_electron_integrals: $(BUILD)/one_electron_integrals
	$(BUILD)/one_electron_integrals $(DATA)/geometry/h2o.xyz $(DATA)/basis_set/def2-svp.gbs

# ---- numeric oracle -------------------------------------------------------
# NVIDIA's C sample computes S/T/V but never prints them, so oracle/ holds a
# copy instrumented to print the same fingerprint as the Fortran port.
CC       ?= gcc
CFLAGS   ?= -O2
COMMON   := $(CUEST_PKG)/CUDALibrarySamples/cuEST/c_examples/common

oracle: $(BUILD)/one_electron_integrals_oracle

$(BUILD)/one_electron_integrals_oracle: oracle/one_electron_integrals_oracle.c | $(BUILD)
	$(CC) $(CFLAGS) -I$(CUEST_PKG)/include -I$(COMMON) $< -o $@ \
	  -L$(CUEST_LIBDIR) -lcuest -L$(CUDA_LIBDIR) -lcudart -lm \
	  -Wl,-rpath,$(CUEST_LIBDIR) -Wl,-rpath,$(CUDA_LIBDIR)

XYZ ?= $(DATA)/geometry/h2o.xyz
GBS ?= $(DATA)/basis_set/def2-svp.gbs

# Run the C reference and the Fortran port on the same input and compare.
compare: $(BUILD)/one_electron_integrals $(BUILD)/one_electron_integrals_oracle
	@$(BUILD)/one_electron_integrals_oracle $(XYZ) $(GBS) > $(BUILD)/c.out
	@$(BUILD)/one_electron_integrals        $(XYZ) $(GBS) > $(BUILD)/f.out
	@python3 compare.py $(BUILD)/c.out $(BUILD)/f.out

clean:
	rm -rf $(BUILD)
