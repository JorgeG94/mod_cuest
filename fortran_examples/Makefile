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

CUEST_PKG   ?= ../..
CUDA_HOME   ?= /usr/local/cuda
FC          ?= gfortran
FFLAGS      ?= -O2 -std=f2008 -Wall
BUILD       := build

CUEST_LIBDIR := $(CUEST_PKG)/lib
CUDA_LIBDIR  ?= $(CUDA_HOME)/lib64
DATA         := $(CUEST_PKG)/CUDALibrarySamples/cuEST/data

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

.PHONY: all clean test $(addprefix run-,$(SAMPLES))

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

clean:
	rm -rf $(BUILD)
