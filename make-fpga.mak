################################################################################
# make-fpga.mak
# Support for using GNU make to drive FPGA builds and simulations.
################################################################################
# TODO
#	check for old ELF files after Vitis build failures

# supported targets/goals
SUPPORTED_FPGA_TOOL:=vivado quartus radiant_cmd radiant_ide
SUPPORTED_SIMULATOR:=ghdl nvc vsim xsim_cmd xsim_ide
SUPPORTED_OTHER:=vcd gtkwave vscode clean

.PHONY: all sim force
.PHONY: $(SUPPORTED_FPGA_TOOL) $(SUPPORTED_SIMULATOR) $(SUPPORTED_OTHER)

ifeq (,$(MAKECMDGOALS))
ifdef FPGA_TOOL
ifneq (,$(filter-out $(SUPPORTED_FPGA_TOOL),$(FPGA_TOOL)))
$(error FPGA_TOOL specifies unsupported tool(s): $(filter-out $(SUPPORTED_FPGA_TOOLS),$(FPGA_TOOL)))
endif
else
$(error FPGA_TOOL not defined, simulator not specified)
endif
endif

ifneq (,$(FPGA_TOOL))
all: $(FPGA_TOOL)
endif

# useful functions
define check_null_error
$(eval $(if $($1),,$(error $1 is empty)))
endef
define check_null_warning
$(eval $(if $($1),,$(info Warning: $1 is empty)))
endef
define check_path
$(if $(filter $1,$(notdir $(word 1,$(shell which $1 2>&1)))),,$(error $1: executable not found in path))
endef
define check_file
$(if $(filter $1,$(wildcard $1)),,$(error $1: file not found))
endef
define check_shell_error
$(if $(filter 0,$(.SHELLSTATUS)),,$(error $1))
endef

# check OS
ifeq ($(OS),Windows_NT)
DUMMY:=$(shell cygpath -w ~)
$(call check_shell_error,Could not run cygpath)
endif

# basic definitions
MAKE_DIR:=$(shell pwd)
MAKE_FPGA_DIR:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ifeq ($(OS),Windows_NT)
MAKE_DIR:=$(shell cygpath -m $(MAKE_DIR))
MAKE_FPGA_DIR:=$(shell cygpath -m $(MAKE_FPGA_DIR))
endif
MAKE_FPGA_TCL:=$(MAKE_FPGA_DIR)/make-fpga.tcl
NULL:=
COMMA:=,
SEMICOLON:=;
SPACE:=$(subst x, ,x)

################################################################################
# FPGA build targets

ifdef FPGA
FPGA_VENDOR?=$(word 1,$(FPGA))
FPGA_FAMILY?=$(word 2,$(FPGA))
FPGA_DEVICE?=$(word 3,$(FPGA))
endif

ifeq (,$(MAKECMDGOALS))
endif

#-------------------------------------------------------------------------------
# AMD/Xilinx Vivado (plus Vitis for MicroBlaze designs)

ifneq (,$(filter vivado,$(FPGA_TOOL)))

vivado: bit

$(call check_null_error,XILINX_VIVADO)
ifeq ($(OS),Windows_NT)
XILINX_VIVADO:=$(shell cygpath -m $(XILINX_VIVADO))
endif

ifdef VITIS_APP

# can't use the name of a phony target as a directory name, so prefix with .
VITIS_DIR?=.vitis

VITIS_EXE:=xsct

VITIS_TCL?=xsct $(MAKE_FPGA_TCL) vitis $(VITIS_APP)
VITIS_ABS_DIR:=$(MAKE_DIR)/$(VITIS_DIR)
VITIS_PROJ_FILE?=$(VITIS_ABS_DIR)/$(VITIS_APP)/$(VITIS_APP).prj
VITIS_ELF_RELEASE?=$(VITIS_ABS_DIR)/$(VITIS_APP)/Release/$(VITIS_APP).elf
VITIS_ELF_DEBUG?=$(VITIS_ABS_DIR)/$(VITIS_APP)/Debug/$(VITIS_APP).elf

endif

# can't use the name of a phony target as a directory name, so prefix with .
VIVADO_DIR?=.vivado

VIVADO_EXE:=vivado
VIVADO_PROJ?=fpga
VIVADO_PART?=$(FPGA_DEVICE)
VIVADO_JOBS?=4

#VIVADO_VER:=$(shell $(VIVADO_EXE) -version | grep -Po '(?<=Vivado\sv)[^\s]+')
VIVADO_TCL:=$(VIVADO_EXE) -mode tcl -notrace -nolog -nojournal -source $(MAKE_FPGA_TCL) -tclargs vivado $(VIVADO_PROJ)
VIVADO_ABS_DIR:=$(MAKE_DIR)/$(VIVADO_DIR)
VIVADO_PROJ_FILE?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).xpr
VIVADO_BIT_FILE?=$(MAKE_DIR)/$(VIVADO_DSN_TOP).bit
VIVADO_IMPL_FILE?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP)_routed.dcp
VIVADO_SYNTH_FILE?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).runs/synth_1/$(VIVADO_DSN_TOP).dcp
VIVADO_XSA_FILE?=$(VIVADO_ABS_DIR)/$(VIVADO_DSN_TOP).xsa
VIVADO_BD_PATH?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).srcs/sources_1/bd
VIVADO_BD_HWDEF_PATH?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).gen/sources_1/bd
VIVADO_SIM_PATH?=$(VIVADO_DIR)/$(VIVADO_PROJ).sim/sim_1/behav/xsim
VIVADO_SIM_IP_PATH?=$(VIVADO_DIR)/$(VIVADO_PROJ).gen/sources_1/ip
VIVADO_DSN_IP_XCI?=$(foreach X,$(basename $(notdir $(VIVADO_DSN_IP_TCL))),$(VIVADO_DSN_IP_PATH)/$X/$X.xci)
VIVADO_DSN_BD?=$(foreach X,$(basename $(notdir $(VIVADO_DSN_BD_TCL))),$(VIVADO_BD_PATH)/$X/$X.bd)
VIVADO_DSN_BD_HWDEF?=$(foreach X,$(basename $(notdir $(VIVADO_DSN_BD_TCL))),$(VIVADO_BD_HWDEF_PATH)/$X/synth/$X.hwdef)
VIVADO_SIM_IP_FILES?=$(foreach X,$(basename $(notdir $(VIVADO_DSN_IP_TCL))),$(addprefix $(VIVADO_SIM_IP_PATH)/,$(VIVADO_SIM_IP_$X)))
ifdef VITIS_APP
VIVADO_DSN_ELF_CFG?=Release
VIVADO_DSN_ELF?=$(VITIS_ABS_DIR)/$(VITIS_APP)/$(VIVADO_DSN_ELF_CFG)/$(VITIS_APP).elf
VIVADO_SIM_ELF_CFG?=Debug
VIVADO_SIM_ELF?=$(VITIS_ABS_DIR)/$(VITIS_APP)/$(VIVADO_SIM_ELF_CFG)/$(VITIS_APP).elf
endif

VIVADO_PROJ_RECIPE_FILE:=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ)_recipe.txt
VIVADO_PROJ_RECIPE_SOURCES:=\
	$(VIVADO_DSN_VHDL) \
	$(VIVADO_DSN_VHDL_2008) \
	$(VIVADO_DSN_IP_TCL) \
	$(VIVADO_DSN_BD_TCL) \
	$(VIVADO_DSN_XDC) \
	$(VIVADO_DSN_XDC_SYNTH) \
	$(VIVADO_DSN_XDC_IMPL) \
	$(VIVADO_SIM_VHDL) \
	$(VIVADO_SIM_VHDL_2008)
VIVADO_PROJ_RECIPE_SETTINGS:=\
	$(VIVADO_DSN_TOP) \
	$(VIVADO_DSN_GENERICS) \
	$(VIVADO_SIM_TOP) \
	$(VIVADO_SIM_GENERICS)
VIVADO_PROJ_RECIPE:=\
	$(VIVADO_PROJ_RECIPE_SOURCES) \
	$(VIVADO_PROJ_RECIPE_SETTINGS)

$(VIVADO_DIR):
	bash -c "mkdir -p $@"

# useful for dependency debug
.PHONY: ts
ts:
	@ls --full-time $(VIVADO_PROJ_RECIPE_FILE)
	@ls --full-time $(VIVADO_PROJ_FILE)
	@ls --full-time $(VIVADO_DSN_BD_TCL)
	@ls --full-time $(VIVADO_DSN_BD)
	@ls --full-time $(VIVADO_DSN_BD_HWDEF)
	@ls --full-time $(VIVADO_XSA_FILE)
	@ls --full-time $(VIVADO_SYNTH_FILE)
	@ls --full-time $(VIVADO_IMPL_FILE)
	@ls --full-time $(VIVADO_BIT_FILE)

# recipe file is created when missing, and updated when the recipe changes
ifneq ($(VIVADO_PROJ_RECIPE),$(file <$(VIVADO_PROJ_RECIPE_FILE)))
$(VIVADO_PROJ_RECIPE_FILE): | $(VIVADO_DIR)
	$(file >$@,$(VIVADO_PROJ_RECIPE))
endif

# project depends on recipe file and existence of sources
.PHONY: xpr
xpr: $(VIVADO_PROJ_FILE)
$(VIVADO_PROJ_FILE): $(VIVADO_PROJ_RECIPE_FILE) | $(VIVADO_PROJ_RECIPE_SOURCES)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: create project
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) create $(VIVADO_PART) vhdl \
		dsn_vhdl:       $(VIVADO_DSN_VHDL) \
		dsn_vhdl_2008:  $(VIVADO_DSN_VHDL_2008) \
		dsn_xdc:        $(VIVADO_DSN_XDC) \
		dsn_xdc_synth:  $(VIVADO_DSN_XDC_SYNTH) \
		dsn_xdc_impl:   $(VIVADO_DSN_XDC_IMPL) \
		dsn_top:        $(VIVADO_DSN_TOP) \
		dsn_gen:        $(VIVADO_DSN_GENERICS) \
		sim_vhdl:       $(VIVADO_SIM_VHDL) \
		sim_vhdl_2008:  $(VIVADO_SIM_VHDL_2008) \
		sim_top:        $(VIVADO_SIM_TOP) \
		sim_gen:        $(VIVADO_SIM_GENERICS)

# BD files depend on BD TCL scripts and existence of project
.PHONY: bd
define RR_VIVADO_BD
bd:: $1
$1: $2 | $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: build block diagrams from TCL
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build bd $1 $2
endef
$(foreach X,$(VIVADO_DSN_BD_TCL),$(eval $(call RR_VIVADO_BD,$(VIVADO_BD_PATH)/$(basename $(notdir $X))/$(basename $(notdir $X)).bd,$X)))

# BD hardware definitions depend on BD files and existence of project
define RR_VIVADO_BD_HWDEF
$1: $2 | $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: build block diagram hardware definitions
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build hwdef $2
endef
$(foreach X,$(VIVADO_DSN_BD_TCL),$(eval $(call RR_VIVADO_BD_HWDEF,$(VIVADO_BD_HWDEF_PATH)/$(basename $(notdir $X))/synth/$(basename $(notdir $X)).hwdef,$(VIVADO_BD_PATH)/$(basename $(notdir $X))/$(basename $(notdir $X)).bd)))

# hardware handoff (XSA) file depends on BD hwdef(s) and existence of project
$(VIVADO_XSA_FILE): $(VIVADO_DSN_BD_HWDEF) | $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: build hardware handoff \(XSA\) file
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build xsa

# IP XCI files and simulation models depend on IP TCL scripts and existence of project
define RR_VIVADO_IP_XCI
$1 $(foreach X,$(VIVADO_SIM_IP_$(basename $(notdir $2))),$(VIVADO_SIM_IP_PATH)/$X) &: $2 | $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: build IP XCI file and simulation model\(s\)
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build ip $1 $2 $(foreach X,$(VIVADO_SIM_IP_$(basename $(notdir $2))),$(VIVADO_SIM_IP_PATH)/$X)
endef
$(foreach X,$(VIVADO_DSN_IP_TCL),$(eval $(call RR_VIVADO_IP_XCI,$(VIVADO_DSN_IP_PATH)/$(basename $(notdir $X))/$(basename $(notdir $X)).xci,$X)))

# synthesis file depends on design sources, relevant constraints and existence of project
$(VIVADO_SYNTH_FILE): $(VIVADO_DSN_IP_XCI) $(VIVADO_DSN_BD_HWDEF) $(VIVADO_DSN_VHDL) $(VIVADO_DSN_VHDL_2008) $(VIVADO_DSN_XDC_SYNTH) $(VIVADO_DSN_XDC) | $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: synthesis
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build synth $(VIVADO_JOBS)

# implementation file depends on synthesis file, ELF file, relevant constraints and existence of project
# we also carry out simulation prep here so that project is left ready for interactive simulation
$(VIVADO_IMPL_FILE): $(VIVADO_SYNTH_FILE) $(VIVADO_DSN_ELF) $(VIVADO_SIM_ELF) $(VIVADO_DSN_XDC_IMPL) $(VIVADO_DSN_XDC) | $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: implementation
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build impl $(VIVADO_JOBS) $(if $VITIS_APP,$(VIVADO_DSN_PROC_INST) $(VIVADO_DSN_PROC_REF) $(VIVADO_DSN_ELF))
	@echo -------------------------------------------------------------------------------
	@echo Vivado: prepare for simulation
	@echo -------------------------------------------------------------------------------
ifdef VITIS_APP
	cd $(VIVADO_DIR) && $(VIVADO_TCL) simprep \
		elf: $(VIVADO_DSN_PROC_INST) $(VIVADO_DSN_PROC_REF) $(VIVADO_SIM_ELF) \
		gen: $(VIVADO_SIM_GENERICS)
else
	cd $(VIVADO_DIR) && $(VIVADO_TCL) simprep \
		gen: $(VIVADO_SIM_GENERICS)
endif
ifneq (,$(VIVADO_DSN_BD_HWDEF))
	touch $(VIVADO_DSN_BD_HWDEF)
endif
ifneq (,$(VIVADO_XSA_FILE))
	touch $(VIVADO_XSA_FILE)
endif
ifdef VITIS_APP
	touch $(VITIS_PROJ_FILE)
	touch $(VITIS_ELF_RELEASE)
	touch $(VITIS_ELF_DEBUG)
endif
	touch $(VIVADO_SYNTH_FILE)
	touch $@

# bit file depends on implementation file
.PHONY: bit
bit: $(VIVADO_BIT_FILE)
$(VIVADO_BIT_FILE): $(VIVADO_IMPL_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: create bit file
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build bit $@

# program FPGA
ifndef hw
ifdef HW
hw:=$(HW)
endif
endif
.PHONY: prog
prog: $(VIVADO_BIT_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: program FPGA
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) prog $< $(hw)

# update BD source TCL scripts from changed BD files
.PHONY: bd_update
define RR_VIVADO_UPDATE_BD
bd_update:: $1 $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vivado: update block diagram TCL
	@echo -------------------------------------------------------------------------------
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build bd_tcl $2 $1
endef
$(foreach X,$(VIVADO_DSN_BD_TCL),$(eval $(call RR_VIVADO_UPDATE_BD,$(VIVADO_BD_PATH)/$(basename $(notdir $X))/$(basename $(notdir $X)).bd,$X)))

ifdef VITIS_APP

# project depends on XSA file (and existence of sources)
$(VITIS_PROJ_FILE): $(VIVADO_XSA_FILE) | $(VITIS_SRC)
	@echo -------------------------------------------------------------------------------
	@echo Vitis: create project
	@echo -------------------------------------------------------------------------------
	rm -rf $(VITIS_DIR)
	bash -c "mkdir -p $(VITIS_DIR)"
	cd $(VITIS_DIR) && $(VITIS_TCL) create $(VITIS_APP) $(VIVADO_XSA_FILE) $(VIVADO_DSN_PROC_INST) \
		src:     $(VITIS_SRC) \
		inc:     $(VITIS_INCLUDE) \
		inc_rls: $(VITIS_INCLUDE_RELEASE) \
		inc_dbg: $(VITIS_INCLUDE_DEBUG) \
		sym:     $(VITIS_SYMBOL) \
		sym_rls: $(VITIS_SYMBOL_RELEASE) \
		sym_dbg: $(VITIS_SYMBOL_DEBUG)

# ELF files depend on XSA file, source and project
.PHONY: elf
elf: $(VITIS_ELF_RELEASE) $(VITIS_ELF_DEBUG)
$(VITIS_ELF_RELEASE) : $(VIVADO_XSA_FILE) $(VITIS_SRC) $(VITIS_SRC_RELEASE) $(VITIS_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vitis: build release binary
	@echo -------------------------------------------------------------------------------
	cd $(VITIS_DIR) && $(VITIS_TCL) build release
$(VITIS_ELF_DEBUG) : $(VIVADO_XSA_FILE) $(VITIS_SRC) $(VITIS_SRC_DEBUG) $(VITIS_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@echo Vitis: build debug binary
	@echo -------------------------------------------------------------------------------
	cd $(VITIS_DIR) && $(VITIS_TCL) build debug

endif

#-------------------------------------------------------------------------------
# Intel/Altera Quartus

else ifneq (,$(filter quartus,$(FPGA_TOOL)))

quartus: sof rbf

# can't use the name of a phony target as a directory name, so prefix with .
QUARTUS_DIR?=.quartus

# basic checks
$(call check_null_error,QUARTUS_ROOTDIR)
ifeq ($(OS),Windows_NT)
QUARTUS_ROOTDIR:=$(shell cygpath -m $(QUARTUS_ROOTDIR))
endif

QUARTUS_SH=$(QUARTUS_PATH:=/)quartus_sh
QUARTUS_MAP=$(QUARTUS_PATH:=/)quartus_map
QUARTUS_FIT=$(QUARTUS_PATH:=/)quartus_fit
QUARTUS_ASM=$(QUARTUS_PATH:=/)quartus_asm
QUARTUS_PGM=$(QUARTUS_PATH:=/)quartus_pgm
QUARTUS_CPF=$(QUARTUS_PATH:=/)quartus_cpf

#QUARTUS_VER:=$(shell $(QUARTUS_SH) --tcl_eval regexp {[\.0-9]+} $quartus(version) ver; puts $ver)
QUARTUS_DIR=quartus

ifndef QUARTUS_PART
$(error QUARTUS_PART not defined)
endif
ifndef QUARTUS_TOP
$(error QUARTUS_TOP not defined)
endif
ifndef QUARTUS_PGM_OPT
QUARTUS_PGM_OPT=-m jtag -c 1
endif

QUARTUS_QPF_FILE=$(QUARTUS_DIR)/$(QUARTUS_TOP).qpf
QUARTUS_MAP_FILE=$(QUARTUS_DIR)/db/$(QUARTUS_TOP).map.cdb
QUARTUS_FIT_FILE=$(QUARTUS_DIR)/db/$(QUARTUS_TOP).cmp.cdb
QUARTUS_SOF_FILE=$(QUARTUS_TOP).sof
QUARTUS_RBF_FILE=$(QUARTUS_TOP).rbf

# TODO recipe

qpf: $(QUARTUS_QPF_FILE)
$(QUARTUS_QPF_FILE): $(QUARTUS_TCL) | $(QUARTUS_QIP) $(QUARTUS_MIF) $(QUARTUS_SIP) $(QUARTUS_VHDL) $(QUARTUS_VLOG) $(QUARTUS_SDC)
	rm -rf $(QUARTUS_DIR)
	mkdir $(QUARTUS_DIR)
	$(QUARTUS_SH) --tcl_eval \
		project_new $(QUARTUS_DIR)/$(QUARTUS_TOP) -revision $(QUARTUS_TOP) -overwrite \;\
		set_global_assignment -name DEVICE $(QUARTUS_PART) \;\
		set_global_assignment -name TOP_LEVEL_ENTITY $(QUARTUS_TOP) \;\
		set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files \;\
		$(addprefix set_global_assignment -name QIP_FILE ,$(QUARTUS_QIP:=\;)) \
		$(addprefix set_global_assignment -name SIP_FILE ,$(QUARTUS_SIP:=\;)) \
		$(addprefix set_global_assignment -name MIF_FILE ,$(QUARTUS_MIF:=\;)) \
		$(addprefix set_global_assignment -name VHDL_FILE ,$(QUARTUS_VHDL:=\;)) \
		$(addprefix set_global_assignment -name VERILOG_FILE ,$(QUARTUS_VLOG:=\;)) \
		$(addprefix set_global_assignment -name SDC_FILE ,$(QUARTUS_SDC:=\;)) \
		$(subst =, ,$(addprefix set_parameter -name ,$(QUARTUS_GEN:=\;))) \
		$(addprefix source ,$(QUARTUS_TCL:=\;))

map: $(QUARTUS_MAP_FILE)
$(QUARTUS_MAP_FILE): $(QUARTUS_QIP) $(QUARTUS_SIP) $(QUARTUS_VHDL) $(QUARTUS_VLOG) | $(QUARTUS_QPF_FILE)
	$(QUARTUS_MAP) \
		$(QUARTUS_DIR)/$(QUARTUS_TOP) \
		--part=$(QUARTUS_PART) \
		$(addprefix --optimize=,$(QUARTUS_MAP_OPTIMIZE)) \
		--rev=$(QUARTUS_TOP)

fit: $(QUARTUS_FIT_FILE)
$(QUARTUS_FIT_FILE): $(QUARTUS_MAP_FILE) $(QUARTUS_MIF) $(QUARTUS_SDC)
	$(QUARTUS_FIT) \
		$(QUARTUS_DIR)/$(QUARTUS_TOP) \
		--effort=$(QUARTUS_FIT_EFFORT) \
		--rev=$(QUARTUS_TOP)

.PHONY: sof
sof: $(QUARTUS_SOF_FILE)
$(QUARTUS_SOF_FILE): $(QUARTUS_FIT_FILE)
	$(QUARTUS_ASM) \
		$(QUARTUS_DIR)/$(QUARTUS_TOP) \
		--rev=$(QUARTUS_TOP)
	mv $(QUARTUS_DIR)/output_files/$(QUARTUS_SOF_FILE) .

.PHONY: rbf
rbf: $(QUARTUS_RBF_FILE)
$(QUARTUS_RBF_FILE): $(QUARTUS_SOF_FILE)
	$(QUARTUS_CPF) -c $(QUARTUS_SOF_FILE) $(QUARTUS_RBF_FILE)

prog: $(QUARTUS_SOF_FILE)
	$(QUARTUS_PGM) $(QUARTUS_PGM_OPT) -o P\;$(QUARTUS_SOF_FILE)$(addprefix @,$(QUARTUS_PGM_DEV))

#-------------------------------------------------------------------------------
# Lattice Radiant

else ifneq (,$(findstring radiant,$(FPGA_TOOL)))

# can't use the name of a phony target as a directory name, so prefix with .
RADIANT_CMD_DIR?=.radiant_cmd
RADIANT_IDE_DIR?=.radiant_ide

# basic checks
$(call check_null_error,LATTICE_RADIANT)
$(call check_null_error,FOUNDRY)
ifeq ($(OS),Windows_NT)
LATTICE_RADIANT:=$(shell cygpath -m $(LATTICE_RADIANT))
endif
ifeq ($(OS),Windows_NT)
RADIANT_EXE:=pnmainc
else
RADIANT_EXE:=radiantc
endif
RADIANT_TCL:=$(RADIANT_EXE) $(MAKE_FPGA_TCL) radiant
#RADIANT_VER:=$(shell $(RADIANT_TCL) script sys_install_version)
#$(call check_shell_status,Could not set RADIANT_VER)

# defaults
RADIANT_PROJ?=fpga
RADIANT_SYNTH?=lse
RADIANT_CORES?=8
RADIANT_DEV_ARCH?=$(FPGA_FAMILY)
RADIANT_DEV?=$(FPGA_DEVICE)
RADIANT_DEV_BASE?=$(word 1,$(subst -, ,$(RADIANT_DEV)))
RADIANT_DEV_PKG?=$(shell echo "iCE40UP5K-SG48I" | grep -Po "(?<=-)(.+\d+)")
ifeq (ICE40UP,$(shell echo '$(RADIANT_DEV_ARCH)' | tr '[:lower:]' '[:upper:]'))
RADIANT_PERF?=High-Performance_1.2V
endif

# errors
ifndef RADIANT_VHDL
ifndef RADIANT_VLOG
$(error No source code specified (RADIANT_VHDL and RADIANT_VLOG undefined))
endif
endif
$(call check_null_error,RADIANT_TOP)

#...............................................................................
# command line flow

ifneq (,$(filter radiant_cmd,$(FPGA_TOOL)))

radiant_cmd: bin nvcm

# warnings
$(call check_null_warning,RADIANT_FREQ)

# build products
RADIANT_SYNTHESIS_VM:=$(RADIANT_PROJ)_synthesis.vm
RADIANT_POSTSYN_UDB:=$(RADIANT_PROJ)_postsyn.udb
RADIANT_MAP_UDB:=$(RADIANT_PROJ)_map.udb
RADIANT_PAR_UDB:=$(RADIANT_PROJ)_par.udb
RADIANT_BIN:=$(RADIANT_PROJ).bin
RADIANT_NVCM:=$(RADIANT_PROJ).nvcm

# rules and recipes

$(RADIANT_CMD_DIR):
	bash -c "mkdir -p $(RADIANT_CMD_DIR)"

$(RADIANT_CMD_DIR)/$(RADIANT_SYNTHESIS_VM): $(RADIANT_VHDL) $(RADIANT_VLOG) $(RADIANT_LDC) | $(RADIANT_CMD_DIR)
	cd $(RADIANT_CMD_DIR) && synthesis \
		-output_hdl $(notdir $@) \
		$(addprefix -vhd ,$(RADIANT_VHDL)) \
		$(addprefix -ver ,$(RADIANT_VLOG)) \
		$(addprefix -sdc ,$(RADIANT_LDC)) \
		-top $(RADIANT_TOP) \
		$(addprefix -frequency ,$(RADIANT_FREQ)) \
		-a $(RADIANT_DEV_ARCH) \
		-p $(RADIANT_DEV_BASE) \
		-t $(RADIANT_DEV_PKG) \
		-sp $(RADIANT_PERF) \
		-logfile $(basename $(notdir $@)).log \
		$(RADIANT_SYNTH_OPTS)

$(RADIANT_CMD_DIR)/$(RADIANT_POSTSYN_UDB): $(RADIANT_CMD_DIR)/$(RADIANT_SYNTHESIS_VM) $(RADIANT_LDC)
	cd $(RADIANT_CMD_DIR) && postsyn \
		-w \
		$(addprefix -a ,$(RADIANT_DEV_ARCH)) \
		$(addprefix -p ,$(RADIANT_DEV_BASE)) \
		$(addprefix -t ,$(RADIANT_DEV_PKG)) \
		$(addprefix -sp ,$(RADIANT_PERF)) \
		$(addprefix -ldc ,$(RADIANT_LDC)) \
		-o $(RADIANT_POSTSYN_UDB) \
		-top \
		$(notdir $<)

$(RADIANT_CMD_DIR)/$(RADIANT_MAP_UDB): $(RADIANT_CMD_DIR)/$(RADIANT_POSTSYN_UDB) $(RADIANT_PDC)
	cd $(RADIANT_CMD_DIR) && map \
		$(RADIANT_POSTSYN_UDB) \
		$(RADIANT_PDC) \
		-o $(notdir $@) \
		-mp $(basename $(RADIANT_MAP_UDB)).mrp \
		-xref_sig \
		-xref_sym

$(RADIANT_CMD_DIR)/$(RADIANT_PAR_UDB): $(RADIANT_CMD_DIR)/$(RADIANT_MAP_UDB) $(RADIANT_PDC)
	cd $(RADIANT_CMD_DIR) && par \
		-w \
		-n 1 \
		-t 1 \
		-stopzero \
		-cores $(RADIANT_CORES) \
		$(RADIANT_MAP_UDB) \
		$(RADIANT_PAR_UDB) \
		$(RADIANT_PDC)

$(RADIANT_BIN): $(RADIANT_CMD_DIR)/$(RADIANT_PAR_UDB)
	cd $(RADIANT_CMD_DIR) && bitgen -w $(notdir $<) $(basename $@) && mv $@ ..

$(RADIANT_NVCM): $(RADIANT_CMD_DIR)/$(RADIANT_PAR_UDB)
	cd $(RADIANT_CMD_DIR) && bitgen -w -nvcm -nvcmsecurity $(notdir $<) $(basename $@) && mv $@ ..

.PHONY: bin
bin: $(RADIANT_BIN)

.PHONY: nvcm
nvcm: $(RADIANT_NVCM)

#...............................................................................
# IDE flow

else ifneq (,$(filter radiant_ide,$(FPGA_TOOL)))

.PHONY: bin nvcm
radiant_ide: bin nvcm

RADIANT_RDF?=$(RADIANT_PROJ).rdf
RADIANT_IMPL?=impl_1

$(RADIANT_IDE_DIR):
	bash -c "mkdir -p $(RADIANT_IDE_DIR)"

$(RADIANT_IDE_DIR)/$(RADIANT_RDF): (ALL MAKEFILES) | $(RADIANT_IDE_DIR)
	cd $(RADIANT_IDE_DIR) && \
	rm -f $(RADIANT_PROJ).rdf && \
	$(RADIANT_TCL) eval \
		prj_create \
		-name		 $(RADIANT_PROJ) \
		-synthesis	 $(RADIANT_SYNTH) \
		-impl		 $(RADIANT_IMPL) \
		-dev		 $(RADIANT_DEV) \
		-performance $(RADIANT_PERF) ; \
		$(addprefix prj_add_source $(RADIANT_VHDL)) ; \
		$(addprefix prj_add_source $(RADIANT_VLOG)) ; \
		$(addprefix prj_add_source $(RADIANT_LDC)) ; \
		$(addprefix prj_add_source $(RADIANT_PDC)) ; \
		prj_set_impl_opt -impl $(RADIANT_IMPL) top $(RADIANT_TOP) ; \
		prj_save

# NOT COMPLETE

#-------------------------------------------------------------------------------

else

$(error Lattice Radiant - unknown flow: $(FPGA_TOOL))

endif

################################################################################

else

ifdef FPGA_TOOL
$(error Unknown FPGA tool: $(FPGA_TOOL))
endif

endif

################################################################################
# simulation targets

# default to all
SIMULATOR?=SUPPORTED_SIMULATOR

# this variable gathers the directories used for the user makefile to refer to
SIM_DIR:=

# defaults
SIM_WORK?=work
SIM_LIB?=$(SIM_WORK)
SIM_SRC.$(SIM_WORK)?=$(SIM_SRC)

# single run: SIM_RUN=top[,generics]
# multiple runs: SIM_RUN=name1,top1[,generics1] name2,top2[,generics2] ...
ifeq ($(words $(SIM_RUN)),1)
SIM_RUN:=$(subst $(COMMA),$(SPACE),$(SIM_RUN))
ifneq (3,$(words $(word 1,$(SIM_RUN))))
SIM_RUN:=sim $(SIM_RUN)
endif
SIM_RUN:=$(subst $(SPACE),$(COMMA),$(SIM_RUN))
endif

#-------------------------------------------------------------------------------
# support for GHDL

ifneq (,$(filter ghdl,$(MAKECMDGOALS)))

ifeq (,$(filter ghdl,$(SIMULATOR)))
$(error This makefile does not support GHDL)
endif

ghdl: sim

# can't use the name of a phony target as a directory name, so prefix with .
GHDL_DIR?=.ghdl
SIM_DIR+=$(GHDL_DIR)
GHDL?=ghdl

GHDL_WORK?=$(SIM_WORK)
GHDL_LIB?=$(SIM_LIB)
$(foreach l,$(GHDL_LIB),$(eval GHDL_SRC.$l?=$(SIM_SRC.$l)))
GHDL_TOUCH_COM:=$(GHDL_DIR)/touch.com
GHDL_TOUCH_RUN:=$(GHDL_DIR)/touch.run
GHDL_PREFIX?=$(dir $(shell which $(GHDL)))/..
ifeq ($(OS),Windows_NT)
GHDL_PREFIX:=$(shell cygpath -m $(GHDL_PREFIX))
endif

GHDL_AOPTS+=--std=08 -fsynopsys -frelaxed -Wno-hide -Wno-shared $(addprefix -P$(GHDL_PREFIX)/lib/ghdl/vendors/,$(GHDL_VENDOR_LIBS))
GHDL_EOPTS+=--std=08 -fsynopsys -frelaxed $(addprefix -P$(GHDL_PREFIX)/lib/ghdl/vendors/,$(GHDL_VENDOR_LIBS))
GHDL_ROPTS+=--max-stack-alloc=0 --ieee-asserts=disable

define ghdl_com
$(GHDL_TOUCH_COM):: $2 | $(GHDL_DIR)
	cd $$(GHDL_DIR) && $$(GHDL) \
		-a \
		--work=$1 \
		$$(GHDL_AOPTS) \
		$2
	touch $(GHDL_TOUCH_COM)
endef

define ghdl_com_lib
$(foreach s,$(GHDL_SRC.$1),$(eval $(call ghdl_com,$1,$s)))
endef

define ghdl_run

$(GHDL_TOUCH_RUN):: $(GHDL_TOUCH_COM) | $(GHDL_DIR)
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  start at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------
	cd $$(GHDL_DIR) && $$(GHDL) \
		--elab-run \
		--work=$$(GHDL_WORK) \
		$$(GHDL_EOPTS) \
		$$(word 2,$1) \
		$$(GHDL_ROPTS) \
		$$(if $$(filter vcd gtkwave,$$(MAKECMDGOALS)),--vcd=$$(word 1,$1).vcd) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  start at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------
	touch $(GHDL_TOUCH_RUN)

sim:: $(GHDL_TOUCH_RUN)

$(GHDL_DIR)/$(word 1,$1).vcd: $(GHDL_TOUCH_RUN)

vcd:: $(GHDL_DIR)/$(word 1,$1).vcd

$(GHDL_DIR)/$(word 1,$1).gtkw: $(GHDL_DIR)/$(word 1,$1).vcd
	sh $(REPO_ROOT)/submodules/vcd2gtkw/vcd2gtkw.sh \
	$(GHDL_DIR)/$(word 1,$1).vcd \
	$(GHDL_DIR)/$(word 1,$1).gtkw

gtkwave:: $(GHDL_DIR)/$(word 1,$1).vcd $(GHDL_DIR)/$(word 1,$1).gtkw
ifeq ($(OS),Windows_NT)
	start gtkwave $(GHDL_DIR)/$(word 1,$1).vcd $(GHDL_DIR)/$(word 1,$1).gtkw
else
	gtkwave $(GHDL_DIR)/$(word 1,$1).vcd $(GHDL_DIR)/$(word 1,$1).gtkw &
endif

endef

$(GHDL_DIR):
	bash -c "mkdir -p $(GHDL_DIR)"

$(foreach l,$(GHDL_LIB),$(eval $(call ghdl_com_lib,$l)))
$(foreach r,$(SIM_RUN),$(eval $(call ghdl_run,$(subst $(COMMA),$(SPACE),$r))))

endif

#-------------------------------------------------------------------------------
# support for NVC

ifneq (,$(filter nvc,$(MAKECMDGOALS)))

ifeq (,$(filter nvc,$(SIMULATOR)))
$(error This makefile does not support NVC)
endif

nvc: sim

# can't use the name of a phony target as a directory name, so prefix with .
NVC_DIR?=.nvc
SIM_DIR+=$(NVC_DIR)
NVC?=nvc

NVC_LIB?=$(SIM_LIB)
$(foreach l,$(NVC_LIB),$(eval NVC_SRC.$l?=$(SIM_SRC.$l)))
NVC_TOUCH_COM:=$(NVC_DIR)/touch.com
NVC_TOUCH_RUN:=$(NVC_DIR)/touch.run

NVC_GOPTS+=--std=2008 -L.
NVC_AOPTS+=--relaxed
NVC_EOPTS+=
NVC_ROPTS+=--ieee-warnings=off

define nvc_com
$(NVC_TOUCH_COM):: $2 | $(NVC_DIR)
	cd $$(NVC_DIR) && $$(NVC) \
		$$(NVC_GOPTS) \
		--work=$1 \
		-a $$(NVC_AOPTS) \
		$2
	touch $(NVC_TOUCH_COM)
endef

define nvc_com_lib
$(foreach s,$(NVC_SRC.$1),$(eval $(call nvc_com,$1,$s)))
endef

define nvc_run

$(NVC_TOUCH_RUN):: $(NVC_TOUCH_COM) | $(NVC_DIR)
	cd $$(NVC_DIR) && $$(NVC) \
		$$(NVC_GOPTS) \
		--work=$$(SIM_WORK) \
		-e $$(word 2,$1) \
		$$(NVC_EOPTS) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  start at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------
	cd $$(NVC_DIR) && $$(NVC) \
		$$(NVC_GOPTS) \
		--work=$$(SIM_WORK) \
		-r $$(word 2,$1) \
		$$(NVC_ROPTS) \
		$$(if $$(filter vcd gtkwave,$$(MAKECMDGOALS)),--format=vcd --wave=$$(word 1,$1).vcd)
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  finish at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------
	touch $(NVC_TOUCH_RUN)

sim:: $(NVC_TOUCH_RUN)

$(NVC_DIR)/$(word 1,$1).vcd: $(NVC_TOUCH_RUN)

vcd:: $(NVC_DIR)/$(word 1,$1).vcd

$(NVC_DIR)/$(word 1,$1).gtkw: $(NVC_DIR)/$(word 1,$1).vcd
	sh $(REPO_ROOT)/submodules/vcd2gtkw/vcd2gtkw.sh \
	$(NVC_DIR)/$(word 1,$1).vcd \
	$(NVC_DIR)/$(word 1,$1).gtkw

gtkwave:: $(NVC_DIR)/$(word 1,$1).vcd $(NVC_DIR)/$(word 1,$1).gtkw
ifeq ($(OS),Windows_NT)
	start gtkwave $(NVC_DIR)/$(word 1,$1).vcd $(NVC_DIR)/$(word 1,$1).gtkw
else
	gtkwave $(NVC_DIR)/$(word 1,$1).vcd $(NVC_DIR)/$(word 1,$1).gtkw &
endif

endef

$(NVC_DIR):
	bash -c "mkdir -p $(NVC_DIR)"

$(foreach l,$(NVC_LIB),$(eval $(call nvc_com_lib,$l)))
$(foreach r,$(SIM_RUN),$(eval $(call nvc_run,$(subst $(COMMA),$(SPACE),$r))))

endif

#-------------------------------------------------------------------------------
# support for vsim (ModelSim/Questa/etc)

ifneq (,$(filter vsim,$(MAKECMDGOALS)))

ifeq (,$(filter vsim,$(SIMULATOR)))
$(error This makefile does not support vsim (ModelSim/Questa/etc))
endif

vsim: sim

# can't use the name of a phony target as a directory name, so prefix with .
VSIM_DIR?=.vsim
SIM_DIR+=$(VSIM_DIR)
VSIM_INI?=modelsim.ini
VMAP?=vmap
VCOM?=vcom
VSIM?=vsim

ifdef VSIM_BIN_DIR
VSIM_BIN_PREFIX:=$(if $(VSIM_BIN_DIR),$(VSIM_BIN_DIR)/,)
ifeq ($(VMAP),$(notdir $(VMAP)))
VMAP:=$(if $(VSIM_BIN_DIR),$(VSIM_BIN_DIR)/,)$(VMAP)
endif
ifeq ($(VCOM),$(notdir $(VCOM)))
VCOM:=$(if $(VSIM_BIN_DIR),$(VSIM_BIN_DIR)/,)$(VCOM)
endif
ifeq ($(VSIM),$(notdir $(VSIM)))
VSIM:=$(if $(VSIM_BIN_DIR),$(VSIM_BIN_DIR)/,)$(VSIM)
endif
endif
ifeq ($(OS),Windows_NT)
VMAP:=$(shell cygpath -m $(VMAP))
VCOM:=$(shell cygpath -m $(VCOM))
VSIM:=$(shell cygpath -m $(VSIM))
endif

VSIM_WORK?=$(SIM_WORK)
VSIM_LIB?=$(SIM_LIB)
$(foreach l,$(VSIM_LIB),$(eval VSIM_SRC.$l?=$(SIM_SRC.$l)))
VSIM_TOUCH_COM:=$(VSIM_DIR)/touch.com
VSIM_TOUCH_RUN:=$(VSIM_DIR)/touch.run

VCOM_OPTS+=-2008 -explicit -stats=none
VSIM_TCL+=set NumericStdNoWarnings 1; onfinish exit; run -all; exit
VSIM_OPTS+=-t ps -c -onfinish stop -do "$(VSIM_TCL)"

define vsim_lib
$(VSIM_DIR)/$1:
	vlib $1
endef

define vsim_com
$(VSIM_TOUCH_COM):: $2 | $(VSIM_DIR) $(VSIM_DIR)/$(VSIM_INI) $(VSIM_DIR)/$1
	cd $$(VSIM_DIR) && $$(VCOM) \
		-modelsimini $(VSIM_INI) \
		-work $1 \
		$$(VCOM_OPTS) \
		$2
	touch $(VSIM_TOUCH_COM)
endef

define vsim_com_lib
$(foreach s,$(VSIM_SRC.$1),$(eval $(call vsim_com,$1,$s)))
endef

define vsim_run

$(VSIM_TOUCH_RUN):: $(VSIM_TOUCH_COM) | $(VSIM_DIR) $(VSIM_DIR)/$(VSIM_INI)
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  start at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------
	cd $$(VSIM_DIR) && $$(VSIM) \
		-modelsimini $(VSIM_INI) \
		-work $$(VSIM_WORK) \
		$$(if $$(filter vcd gtkwave,$$(MAKECMDGOALS)),-do "vcd file $$(word 1,$1).vcd; vcd add -r *") \
		$$(VSIM_OPTS) \
		$$(word 2,$1) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  finish at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------
	touch $(VSIM_TOUCH_RUN)

sim:: $(VSIM_TOUCH_RUN)

$(VSIM_DIR)/$(word 1,$1).vcd: $(VSIM_TOUCH_RUN)

vcd:: $(VSIM_DIR)/$(word 1,$1).vcd

$(VSIM_DIR)/$(word 1,$1).gtkw: $(VSIM_DIR)/$(word 1,$1).vcd
	sh $(REPO_ROOT)/submodules/vcd2gtkw/vcd2gtkw.sh \
	$(VSIM_DIR)/$(word 1,$1).vcd \
	$(VSIM_DIR)/$(word 1,$1).gtkw

gtkwave:: $(VSIM_DIR)/$(word 1,$1).vcd $(VSIM_DIR)/$(word 1,$1).gtkw
ifeq ($(OS),Windows_NT)
	start cmd.exe //C \"gtkwave $(VSIM_DIR)/$(word 1,$1).vcd $(VSIM_DIR)/$(word 1,$1).gtkw\"
else
	gtkwave $(VSIM_DIR)/$(word 1,$1).vcd $(VSIM_DIR)/$(word 1,$1).gtkw &
endif

endef

$(VSIM_DIR):
	bash -c "mkdir -p $(VSIM_DIR)"

$(VSIM_DIR)/$(VSIM_INI): | $(VSIM_DIR)
	cd $(VSIM_DIR) && $(VMAP) -c && mv modelsim.ini $(VSIM_INI)

$(foreach l,$(VSIM_LIB),$(eval $(call vsim_lib,$l)))
$(foreach l,$(VSIM_LIB),$(eval $(call vsim_com_lib,$l)))
$(foreach r,$(SIM_RUN),$(eval $(call vsim_run,$(subst $(COMMA),$(SPACE),$r))))

endif

#-------------------------------------------------------------------------------
# support for xsim (Vivado simulator)

ifneq (,$(filter xsim_cmd xsim_ide,$(MAKECMDGOALS)))

ifeq (,$(filter xsim_cmd xsim_ide,$(SIMULATOR)))
$(error This makefile does not support XSim)
endif

#...............................................................................
# command line flow

ifneq (,$(filter xsim_cmd,$(MAKECMDGOALS)))

xsim_cmd: sim

# can't use the name of a phony target as a directory name, so prefix with .
XSIM_CMD_DIR?=.xsim_cmd
SIM_DIR+=$(XSIM_CMD_DIR)
XVHDL?=xvhdl
XELAB?=xelab
XSIM?=xsim

XSIM_CMD_LIB?=$(SIM_LIB)
$(foreach l,$(XSIM_CMD_LIB),$(eval XSIM_CMD_SRC.$l?=$(SIM_SRC.$l)))
XSIM_CMD_TOUCH_COM:=$(XSIM_CMD_DIR)/touch.com
XSIM_CMD_TOUCH_RUN:=$(XSIM_CMD_DIR)/touch.run

XVHDL_OPTS+=-2008 -relax
XELAB_OPTS+=-debug typical -O2 -relax
XSIM_OPTS+=-onerror quit -onfinish quit

ifeq ($(OS),Windows_NT)

define xsim_cmd_com

$(XSIM_CMD_TOUCH_COM):: $2 | $(XSIM_CMD_DIR)
	bash -c "cd $$(XSIM_CMD_DIR) && cmd.exe //C \"$(XVHDL).bat \
		$$(XVHDL_OPTS) \
		-work $1 \
		$(shell cygpath -w $2) \
		\""
	touch $(XSIM_CMD_TOUCH_COM)

endef

define xsim_cmd_run

$(XSIM_CMD_TOUCH_RUN):: $(XSIM_CMD_TOUCH_COM)
	$$(file >$$(XSIM_CMD_DIR)/$$(word 1,$1)_run.tcl, \
		$(if $(filter vcd gtkwave,$(MAKECMDGOALS)), \
		open_vcd $$(word 1,$1).vcd; log_vcd /*; run all; close_vcd; quit, \
		run all; quit \
		) \
	)
	$$(file >$$(XSIM_CMD_DIR)/$$(word 1,$1)_elab.bat, \
		$$(XELAB).bat \
			$$(XELAB_OPTS) \
			-L $$(SIM_WORK) \
			-top $$(word 2,$1) \
			-snapshot $$(word 2,$1)_$$(word 1,$1) \
			$$(addprefix -generic_top ",$$(addsuffix ",$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))) \
	)
	$$(file >$$(XSIM_CMD_DIR)/$$(word 1,$1)_sim.bat, \
		$$(XSIM).bat \
			$$(XSIM_OPTS) \
			-tclbatch $$(word 1,$1)_run.tcl \
			$$(word 2,$1)_$$(word 1,$1) \
	)
	bash -c "cd $$(XSIM_CMD_DIR) && cmd.exe //C $$(word 1,$1)_elab.bat"
	@echo -------------------------------------------------------------------------------
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
	@echo -------------------------------------------------------------------------------
	bash -c "cd $$(XSIM_CMD_DIR) && cmd.exe //C $$(word 1,$1)_sim.bat"
	@echo -------------------------------------------------------------------------------
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
	@echo -------------------------------------------------------------------------------
	touch $(XSIM_CMD_TOUCH_RUN)

sim:: $(XSIM_CMD_TOUCH_RUN)

$(XSIM_CMD_DIR)/$(word 1,$1).vcd: $(XSIM_CMD_TOUCH_RUN)

vcd:: $(XSIM_CMD_DIR)/$(word 1,$1).vcd

$(XSIM_CMD_DIR)/$(word 1,$1).gtkw: $(XSIM_CMD_DIR)/$(word 1,$1).vcd
	sh $(REPO_ROOT)/submodules/vcd2gtkw/vcd2gtkw.sh \
	$(XSIM_CMD_DIR)/$(word 1,$1).vcd \
	$(XSIM_CMD_DIR)/$(word 1,$1).gtkw

gtkwave:: $(XSIM_CMD_DIR)/$(word 1,$1).vcd $(XSIM_CMD_DIR)/$(word 1,$1).gtkw
	start cmd.exe //C \"gtkwave $(XSIM_CMD_DIR)/$(word 1,$1).vcd $(XSIM_CMD_DIR)/$(word 1,$1).gtkw\"

endef

else

define xsim_cmd_com

$(XSIM_CMD_TOUCH_COM):: $1 | $(XSIM_CMD_DIR)
	cd $$(SIM_DIR) && $$(XVHDL) \
		$$(XVHDL_OPTS) \
		-work $1 \
		$2
	touch $(XSIM_CMD_TOUCH_COM)

endef

define xsim_cmd_run

$$(file >$$(XSIM_CMD_DIR)/$$(word 1,$1)_run.tcl, \
	$(if $(filter vcd gtkwave,$(MAKECMDGOALS)), \
	open_vcd $$(word 1,$1).vcd; log_vcd /*; run all; close_vcd; quit, \
	run all; quit \
	) \
)

$(XSIM_CMD_TOUCH_RUN):: $(XSIM_CMD_TOUCH_COM)
	cd $$(XSIM_CMD_DIR) && $$(XELAB) \
		$$(XELAB_OPTS) \
		-L $$(SIM_WORK) \
		-top $$(word 2,$1) \
		-snapshot $$(word 2,$1)_$$(word 1,$1) $$(word 2,$1) \
		$(addprefix -generic_top ,$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
	@echo -------------------------------------------------------------------------------
	echo simulation run: $$(word 1,$1)  start at: $(date +"%T.%2N")
	@echo -------------------------------------------------------------------------------
	cd $$(XSIM_CMD_DIR) && $$(XSIM) \
		$$(XSIM_OPTS) \
		-tclbatch $$(word 1,$1)_run.tcl \
		$$(word 2,$1)_$$(word 1,$1)
	@echo -------------------------------------------------------------------------------
	@echo simulation run: $$(word 1,$1)  finish at: $(date +"%T.%2N")
	@echo -------------------------------------------------------------------------------
	touch $(XSIM_CMD_TOUCH_RUN)

sim:: $(XSIM_CMD_TOUCH_RUN)

$(XSIM_CMD_DIR)/$(word 1,$1).vcd: $(XSIM_CMD_TOUCH_RUN)

vcd:: $(XSIM_CMD_DIR)/$(word 1,$1).vcd

$(XSIM_CMD_DIR)/$(word 1,$1).gtkw: $(XSIM_CMD_DIR)/$(word 1,$1).vcd
	sh $(REPO_ROOT)/submodules/vcd2gtkw/vcd2gtkw.sh \
	$(XSIM_CMD_DIR)/$(word 1,$1).vcd \
	$(XSIM_CMD_DIR)/$(word 1,$1).gtkw

gtkwave:: $(XSIM_CMD_DIR)/$(word 1,$1).vcd $(XSIM_CMD_DIR)/$(word 1,$1).gtkw
	gtkwave $(XSIM_CMD_DIR)/$(word 1,$1).vcd $(XSIM_CMD_DIR)/$(word 1,$1).gtkw &

endef

endif

define xsim_cmd_com_lib
$(foreach s,$(XSIM_CMD_SRC.$1),$(eval $(call xsim_cmd_com,$1,$s)))
endef

$(XSIM_CMD_DIR):
	bash -c "mkdir -p $(XSIM_CMD_DIR)"

$(foreach l,$(XSIM_CMD_LIB),$(eval $(call xsim_cmd_com_lib,$l)))
$(foreach r,$(SIM_RUN),$(eval $(call xsim_cmd_run,$(subst $(COMMA),$(SPACE),$r))))

endif

#...............................................................................
# IDE flow

ifneq (,$(filter xsim_ide,$(MAKECMDGOALS)))

xsim_ide: sim

# basic checks
VIVADO_EXE:=vivado
VIVADO_TCL:=$(VIVADO_EXE) -mode tcl -notrace -nolog -nojournal -source $(MAKE_FPGA_TCL) -tclargs eval

# can't use the name of a phony target as a directory name, so prefix with .
XSIM_IDE_DIR?=.xsim_ide
SIM_DIR+=$(XSIM_IDE_DIR)

XSIM_IDE_LIB?=$(SIM_LIB)
$(foreach l,$(XSIM_IDE_LIB),$(eval XSIM_IDE_SRC.$l?=$(SIM_SRC.$l)))

VIVADO_PROJ?=xsim
VIVADO_PROJ_FILE?=$(XSIM_IDE_DIR)/$(VIVADO_PROJ).xpr

$(XSIM_IDE_DIR):
	bash -c "mkdir -p $(XSIM_IDE_DIR)"

$(VIVADO_PROJ_FILE): $(foreach l,$(XSIM_IDE_LIB),$(XSIM_IDE_SRC.$l)) | $(XSIM_IDE_DIR)
	cd $(XSIM_IDE_DIR) && $(VIVADO_TCL) \
		"create_project -force $(VIVADO_PROJ); \
		set_property target_language VHDL [get_projects $(VIVADO_PROJ)]; \
		add_files -norecurse -fileset [get_filesets sim_1] {$(foreach l,$(XSIM_IDE_LIB),$(XSIM_IDE_SRC.$l))}; \
		set_property file_type \"VHDL 2008\" [get_files -of_objects [get_filesets sim_1] {$(foreach l,$(SIM_LIB),$(SIM_SRC.$l))}]; \
		set_property used_in_synthesis false [get_files -of_objects [get_filesets sim_1] {$(foreach l,$(SIM_LIB),$(SIM_SRC.$l))}]; \
		set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]; \
		$(foreach l,$(XSIM_IDE_LIB),set_property library $l [get_files -of_objects [get_filesets sim_1] {$(XSIM_IDE_SRC.$l)}]; ) exit"

define xsim_ide_run

sim:: | $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
	@echo -------------------------------------------------------------------------------
	cd $(XSIM_IDE_DIR) && $(VIVADO_TCL) \
		"open_project $(VIVADO_PROJ); \
		set_property top $$(word 2,$1) [get_filesets sim_1]; \
		$(if $(word 3,$1),set_property generic {$(subst $(SEMICOLON),$(SPACE),$(word 3,$1))} [get_filesets sim_1];) \
		puts \"Run: $$(word 1,$1)\"; \
		launch_simulation; \
		run all; \
		exit"
	@echo -------------------------------------------------------------------------------
	@bash -c "cmd.exe //C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
	@echo -------------------------------------------------------------------------------

endef

$(foreach r,$(SIM_RUN),$(eval $(call xsim_ide_run,$(subst $(COMMA),$(SPACE),$r))))

ifneq (,$(word 2,$(SIM_RUN)))
# ensure that simulator is left set up for first run
sim::
	cd $(XSIM_IDE_DIR) && $(VIVADO_TCL) \
		"open_project $(VIVADO_PROJ); \
		set_property top $(word 2,$(subst $(COMMA),$(SPACE),$(word 1,$(SIM_RUN)))) [get_filesets sim_1]; \
		set_property generic {$(subst $(SEMICOLON),$(SPACE),$(word 3,$(subst $(COMMA),$(SPACE),$(word 1,$(SIM_RUN)))))} [get_filesets sim_1]; \
		exit"
endif

endif

endif

################################################################################
# Visual Studio Code including V4P extension

VSCODE:=code
VSCODE_DIR:=.vscode

ifndef VSCODE_LIB
VSCODE_LIB:=$(SIM_LIB)
endif
ifdef VSCODE_SRC
VSCODE_SRC.work:=$(VSCODE_SRC)
else
$(foreach l,$(VSCODE_LIB),$(eval VSCODE_SRC.$l?=$(SIM_SRC.$l)))
endif
VSCODE_TOP?=$(SIM_TOP)
V4P_TOP?=$(VSCODE_TOP)
VSCODE_LIBX:=$(filter-out $(VSCODE_LIB),$(VSCODE_XLIB))
VSCODE_LIB+=$(VSCODE_LIBX)
$(foreach l,$(VSCODE_XLIB),$(eval VSCODE_SRC.$l+=$(VSCODE_XSRC.$l)))
define RR_VSCODE_DIR
$1:
	bash -c "mkdir -p $1"
endef
$(eval $(call RR_VSCODE_DIR,$(VSCODE_DIR)))
$(foreach l,$(VSCODE_LIB),$(eval $(call RR_VSCODE_DIR,$(VSCODE_DIR)/$l)))
define RR_VSCODE_SYMLINK
ifeq ($(OS),Windows_NT)
$(VSCODE_DIR)/$1/$(notdir $2): $2 | $(VSCODE_DIR)/$1
	rm -f $$@
	bash -c "cmd.exe //C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
else
$(VSCODE_DIR)/$1/$(notdir $2): $2 | $(VSCODE_DIR)/$1
	ln $$< $$@
endif
endef
$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),$(eval $(call RR_VSCODE_SYMLINK,$l,$s))))
VSCODE_SYMLINKS:=$(foreach l,$(VSCODE_LIB),$(addprefix $(VSCODE_DIR)/$l/,$(notdir $(VSCODE_SRC.$l))))
CONFIG_V4P_FILE:=$(VSCODE_DIR)/config.v4p
CONFIG_V4P_LINES:= \
	[libraries] \
	$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),$l/$(notdir $s)=$l)) \
	[settings] \
	V4p.Settings.Basics.TopLevelEntities=$(V4P_TOP)
force:
$(CONFIG_V4P_FILE): force | $(VSCODE_DIR)
	bash -c 'l=( $(CONFIG_V4P_LINES) ); printf "%s\n" "$${l[@]}" > $(CONFIG_V4P_FILE)'
vscode: $(VSCODE_SYMLINKS) $(CONFIG_V4P_FILE)
	$(VSCODE) $(VSCODE_DIR)

#################################################################################
# cleanup

clean:
	find . -type f -not \( -name 'makefile' -or -name '.gitignore' \) -delete
	find . -type d -not \( -name '.' -or -name '..' \) -exec rm -rf {} +
