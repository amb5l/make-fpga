################################################################################
# radiant.mak
# A part of make-fpga: see https://github.com/amb5l/make-fpga
################################################################################
# Lattice Radiant support
#
# Required definitions:
#	RADIANT_ARCH                      Architecture/Family e.g. ice40up
#	RADIANT_DEV                       Device e.g. iCE40UP5K-SG48I
#	RADIANT_VHDL and/or RADIANT_VLOG  Source
#	RADIANT_TOP                       Top entity/module name
# Optional definitions:
#	RADIANT_PERF                      e.g. High-Performance_1.2V
#	RADIANT_FREQ                      e.g. 33.3MHz
#	RADIANT_LDC                       Pre-synthesis constraints
#	RADIANT_PDC                       Post-synthesis constraints
# Optional definitions (IDE flow only):
#	RADIANT_RDF                       Project filename (e.g. fpga.rdf)
#	RADIANT_IMPL                      Implementation name (e.g. impl_1)
################################################################################

.PHONY: radiant
radiant: bin nvcm tsim

REPO_ROOT?=$(shell git rev-parse --show-toplevel)
ifeq ($(OS),Windows_NT)
REPO_ROOT?=$(shell cygpath -m $(REPO_ROOT))
endif
MAKE_FPGA?=$(REPO_ROOT)/submodules/make-fpga
include $(MAKE_FPGA)/utils.mak

$(call check_null_error,LATTICE_RADIANT)
$(call check_null_error,FOUNDRY)
ifeq ($(OS),Windows_NT)
LATTICE_RADIANT:=$(shell cygpath -m $(LATTICE_RADIANT))
endif

# defaults
RADIANT_DIR?=.radiant
RADIANT_PROJ?=fpga
RADIANT_CORES?=$(shell expr $(CPU_CORES) / 2)

ifeq (ICE40UP,$(shell echo $(RADIANT_ARCH)| tr '[:lower:]' '[:upper:]'))
RADIANT_PERF?=High-Performance_1.2V
endif

#...............................................................................
# command line flow

ifeq (cmd,$(RADIANT_FLOW))

# executables
RADIANT_SYNTHESIS:=synthesis
RADIANT_POSTSYN:=postsyn
RADIANT_MAP:=map
RADIANT_PAR:=par
RADIANT_BITGEN:=bitgen
RADIANT_BACKANNO:=backanno

# build products
RADIANT_SYNTHESIS_VM:=$(RADIANT_PROJ)_synthesis.vm
RADIANT_POSTSYN_UDB:=$(RADIANT_PROJ)_postsyn.udb
RADIANT_MAP_UDB:=$(RADIANT_PROJ)_map.udb
RADIANT_PAR_UDB:=$(RADIANT_PROJ)_par.udb
RADIANT_BIN:=$(RADIANT_PROJ).bin
RADIANT_NVCM:=$(RADIANT_PROJ).nvcm
RADIANT_VO:=$(RADIANT_PROJ)_vo.vo
RADIANT_SDF:=$(RADIANT_PROJ)_vo.sdf

# rules and recipes

$(RADIANT_DIR):
	bash -c "mkdir -p $(RADIANT_DIR)"

$(RADIANT_DIR)/$(RADIANT_SYNTHESIS_VM): $(RADIANT_VHDL) $(RADIANT_VLOG) $(RADIANT_LDC) | $(RADIANT_DIR)
	$(call check_null_error,RADIANT_ARCH)
	$(call check_null_error,RADIANT_DEV)
	$(call check_null_error,RADIANT_TOP)
	cd $(RADIANT_DIR) && $(RADIANT_SYNTHESIS) \
		-output_hdl $(notdir $@) \
		$(addprefix -vhd ,$(RADIANT_VHDL)) \
		$(addprefix -ver ,$(RADIANT_VLOG)) \
		$(addprefix -sdc ,$(RADIANT_LDC)) \
		-top $(RADIANT_TOP) \
		$(addprefix -frequency ,$(RADIANT_FREQ)) \
		-a $(RADIANT_ARCH) \
		-p $(word 1,$(subst -, ,$(RADIANT_DEV))) \
		-t $(shell echo $(RADIANT_DEV)| grep -Po "(?<=-)(.+\d+)") \
		-sp $(RADIANT_PERF) \
		-logfile $(basename $(notdir $@)).log \
		$(RADIANT_SYNTH_OPTS)

$(RADIANT_DIR)/$(RADIANT_POSTSYN_UDB): $(RADIANT_DIR)/$(RADIANT_SYNTHESIS_VM) $(RADIANT_LDC)
	$(call check_null_error,RADIANT_ARCH)
	$(call check_null_error,RADIANT_DEV)
	cd $(RADIANT_DIR) && $(RADIANT_POSTSYN) \
		-w \
		-a $(RADIANT_ARCH) \
		-p $(word 1,$(subst -, ,$(RADIANT_DEV))) \
		-t $(shell echo $(RADIANT_DEV)| grep -Po "(?<=-)(.+\d+)") \
		$(addprefix -sp ,$(RADIANT_PERF)) \
		$(addprefix -ldc ,$(RADIANT_LDC)) \
		-o $(RADIANT_POSTSYN_UDB) \
		-top \
		$(notdir $<)

$(RADIANT_DIR)/$(RADIANT_MAP_UDB): $(RADIANT_DIR)/$(RADIANT_POSTSYN_UDB) $(RADIANT_PDC)
	cd $(RADIANT_DIR) && $(RADIANT_MAP) \
		$(RADIANT_POSTSYN_UDB) \
		$(RADIANT_PDC) \
		-o $(notdir $@) \
		-mp $(basename $(RADIANT_MAP_UDB)).mrp \
		-xref_sig \
		-xref_sym

$(RADIANT_DIR)/$(RADIANT_PAR_UDB): $(RADIANT_DIR)/$(RADIANT_MAP_UDB) $(RADIANT_PDC)
	cd $(RADIANT_DIR) && $(RADIANT_PAR) \
		-w \
		-n 1 \
		-t 1 \
		-stopzero \
		-cores $(RADIANT_CORES) \
		$(RADIANT_MAP_UDB) \
		$(RADIANT_PAR_UDB)

$(RADIANT_BIN): $(RADIANT_DIR)/$(RADIANT_PAR_UDB)
	cd $(RADIANT_DIR) && \
	$(RADIANT_BITGEN) -w $(notdir $<) $(basename $(notdir $@)) && \
	mv $(notdir $@) ..

$(RADIANT_NVCM): $(RADIANT_DIR)/$(RADIANT_PAR_UDB)
	cd $(RADIANT_DIR) && \
	$(RADIANT_BITGEN) -w -nvcm -nvcmsecurity $(notdir $<) $(basename $(notdir $@)) && \
	mv $(notdir $@) ..

$(RADIANT_DIR)/$(RADIANT_VO) $(RADIANT_DIR)/$(RADIANT_SDF): $(RADIANT_DIR)/$(RADIANT_PAR_UDB)
	cd $(RADIANT_DIR) && $(RADIANT_BACKANNO) \
		-w \
		-neg \
		-x \
		-o $(RADIANT_VO) \
		-d $(RADIANT_SDF) \
		$(RADIANT_PAR_UDB)

.PHONY: bin nvcm tsim
bin: $(RADIANT_BIN)
nvcm: $(RADIANT_NVCM)
tsim: $(RADIANT_DIR)/$(RADIANT_VO) $(RADIANT_DIR)/$(RADIANT_SDF)

#...............................................................................
# IDE flow

else ifeq (ide,$(RADIANT_FLOW))

# NOT COMPLETE

#-------------------------------------------------------------------------------

else ifeq (,$(RADIANT_FLOW))
$(error Lattice Radiant - flow not specified (RADIANT_FLOW is empty))
else
$(error Lattice Radiant - unknown flow (RADIANT_FLOW=$(RADIANT_FLOW)))
endif
