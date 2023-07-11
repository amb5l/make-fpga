################################################################################
# make-fpga.mak
# Support for using GNU make to drive FPGA builds and simulations.
################################################################################
# TODO
#	check for old ELF files after Vitis build failures

# supported targets/goals
SUPPORTED_FPGA_TOOL:=vivado quartus radiant_cmd radiant_ide
SUPPORTED_SIMULATOR:=ghdl nvc vsim xsim_cmd xsim_ide
SUPPORTED_OTHER:=gtkwave vscode clean

.PHONY: all sim force
.PHONY: $(SUPPORTED_FPGA_TOOL) $(SUPPORTED_SIMULATOR) $(SUPPORTED_OTHER)

ifeq (,$(MAKECMDGOALS))
ifdef FPGA_TOOL
ifneq (,$(filter-out $(SUPPORTED_FPGA_TOOL),$(FPGA_TOOL)))
$(error FPGA_TOOL specifies unsupported tool(s): $(filter-out $(SUPPORTED_FPGA_TOOLS),$(FPGA_TOOL)))
endif
else
ifneq (default,$(.DEFAULT_GOAL))
$(error FPGA_TOOL not defined, simulator not specified)
endif
endif
MAKECMDGOALS:=all
endif

all: $(FPGA_TOOL)
force:

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
$(call check_null_error,MSYS2)
MSYS2:=$(shell cygpath -m $(MSYS2))
export PATH:=$(MSYS2)/usr/bin:$(PATH)
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
COL_RST:=\033[0m
COL_BG_BLK:=\033[0;100m
COL_BG_RED:=\033[0;101m
COL_BG_GRN:=\033[0;102m
COL_BG_YEL:=\033[0;103m
COL_BG_BLU:=\033[0;104m
COL_BG_MAG:=\033[0;105m
COL_BG_CYN:=\033[0;106m
COL_BG_WHT:=\033[0;107m
COL_FG_BLK:=\033[1;30m
COL_FG_RED:=\033[1;31m
COL_FG_GRN:=\033[1;32m
COL_FG_YEL:=\033[1;33m
COL_FG_BLU:=\033[1;34m
COL_FG_MAG:=\033[1;35m
COL_FG_CYN:=\033[1;36m
COL_FG_WHT:=\033[1;37m
CPU_CORES:=$(shell bash -c "grep '^core id' /proc/cpuinfo |sort -u|wc -l")

# includes
include $(MAKE_FPGA_DIR)/submodules/gmsl/gmsl

#################################################################################
# cleanup

clean:
ifeq ($(OS),Windows_NT)
	bash -c "/usr/bin/find . -type f -not \( -name 'makefile' -or -name '.gitignore' \) -delete"
	bash -c "/usr/bin/find . -type d -not \( -name '.' -or -name '..' \) -exec rm -rf {} +"
else
	find . -type f -not \( -name 'makefile' -or -name '.gitignore' \) -delete
	find . -type d -not \( -name '.' -or -name '..' \) -exec rm -rf {} +
endif

################################################################################
# FPGA build targets

ifdef FPGA
FPGA_VENDOR?=$(word 1,$(FPGA))
FPGA_FAMILY?=$(word 2,$(FPGA))
FPGA_DEVICE?=$(word 3,$(FPGA))
endif

#-------------------------------------------------------------------------------
# AMD/Xilinx Vivado (plus Vitis for MicroBlaze/ARM designs)

ifneq (,$(filter vivado,$(FPGA_TOOL)))
VIVADO_TARGETS:=all xpr bd bit prog bd_update elf run
ifneq (,$(filter $(VIVADO_TARGETS),$(MAKECMDGOALS)))

vivado:: bit

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
VITIS_ARCH?=microblaze
ifeq (microblaze,$(VITIS_ARCH))
VITIS_PROC?=$(VIVADO_DSN_PROC_INST)
endif
ifeq (arm,$(VITIS_ARCH))
VITIS_PROC?=ps7_cortexa9_0
VITIS_OS?=standalone
VITIS_DOMAIN?=$(VITIS_OS)_domain
VITIS_ELF_FSBL?=$(VITIS_ABS_DIR)/$(VIVADO_DSN_TOP)/zynq_fsbl/fsbl.elf
VITIS_HW_INIT_TCL?=$(VITIS_ABS_DIR)/$(VIVADO_DSN_TOP)/hw/ps7_init.tcl
vivado:: elf
endif

endif

# can't use the name of a phony target as a directory name, so prefix with .
VIVADO_DIR?=.vivado

VIVADO_EXE:=vivado
VIVADO_PROJ?=fpga
VIVADO_PART?=$(FPGA_DEVICE)
VIVADO_JOBS?=$(shell expr $(CPU_CORES) / 2)

#VIVADO_VER:=$(shell $(VIVADO_EXE) -version | grep -Po '(?<=Vivado\sv)[^\s]+')
VIVADO_TCL:=$(VIVADO_EXE) -mode tcl -notrace -nolog -nojournal -source $(MAKE_FPGA_TCL) -tclargs vivado $(VIVADO_PROJ)
VIVADO_ABS_DIR:=$(MAKE_DIR)/$(VIVADO_DIR)
VIVADO_PROJ_FILE?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).xpr
VIVADO_BIT_FILE?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP).bit
VIVADO_SYNTH_FILE?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).runs/synth_1/$(VIVADO_DSN_TOP).dcp
VIVADO_XSA_FILE?=$(VIVADO_ABS_DIR)/$(VIVADO_DSN_TOP).xsa
VIVADO_DSN_IP_PATH?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).srcs/sources_1/ip
VIVADO_BD_PATH?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).srcs/sources_1/bd
VIVADO_BD_SCP_MODE?=Hierarchical
VIVADO_BD_HWDEF_PATH?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).gen/sources_1/bd
VIVADO_SIM_PATH?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).sim/sim_1/behav/xsim
VIVADO_SIM_IP_PATH?=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ).gen/sources_1/ip
VIVADO_DSN_IP_XCI?=$(foreach X,$(basename $(notdir $(VIVADO_DSN_IP_TCL))),$(VIVADO_DSN_IP_PATH)/$X/$X.xci)
VIVADO_DSN_BD?=$(foreach X,$(basename $(notdir $(VIVADO_DSN_BD_TCL))),$(VIVADO_BD_PATH)/$X/$X.bd)
VIVADO_DSN_BD_HWDEF?=$(foreach X,$(basename $(notdir $(VIVADO_DSN_BD_TCL))),$(VIVADO_BD_HWDEF_PATH)/$X/synth/$X.hwdef)
VIVADO_SIM_IP_FILES?=$(foreach X,$(basename $(notdir $(VIVADO_DSN_IP_TCL))),$(addprefix $(VIVADO_SIM_IP_PATH)/,$(VIVADO_SIM_IP_$X)))
ifdef VITIS_APP
ifeq (microblaze,$(VITIS_ARCH))
VIVADO_DSN_ELF_CFG?=Release
VIVADO_DSN_ELF?=$(VITIS_ABS_DIR)/$(VITIS_APP)/$(VIVADO_DSN_ELF_CFG)/$(VITIS_APP).elf
VIVADO_SIM_ELF_CFG?=Debug
VIVADO_SIM_ELF?=$(VITIS_ABS_DIR)/$(VITIS_APP)/$(VIVADO_SIM_ELF_CFG)/$(VITIS_APP).elf
endif
endif

VIVADO_PROJ_RECIPE_FILE:=$(VIVADO_ABS_DIR)/$(VIVADO_PROJ)_recipe.txt
VIVADO_PROJ_RECIPE_SOURCES=\
	$(VIVADO_DSN_VHDL) \
	$(VIVADO_DSN_VHDL_2008) \
	$(VIVADO_DSN_IP_TCL) \
	$(VIVADO_DSN_BD_TCL) \
	$(VIVADO_DSN_XDC) \
	$(VIVADO_DSN_XDC_SYNTH) \
	$(VIVADO_DSN_XDC_IMPL) \
	$(VIVADO_SIM_VHDL) \
	$(VIVADO_SIM_VHDL_2008)
VIVADO_PROJ_RECIPE_SETTINGS=\
	$(VIVADO_DSN_TOP) \
	$(VIVADO_DSN_GENERICS) \
	$(VIVADO_SIM_TOP) \
	$(VIVADO_SIM_GENERICS)
VIVADO_PROJ_RECIPE=\
	$(VIVADO_PROJ_RECIPE_SOURCES) \
	$(VIVADO_PROJ_RECIPE_SETTINGS)

$(VIVADO_DIR):
	bash -c "mkdir -p $@"

# recipe file is created/updated as required
$(VIVADO_PROJ_RECIPE_FILE): force | $(VIVADO_DIR)
	@bash -c '[ -f $@ ] && r=$$(< $@) || r=""; if [[ $$r != "$(VIVADO_PROJ_RECIPE)" ]]; then \
	echo "$(VIVADO_PROJ_RECIPE)" > $@; fi'

# project depends on recipe file and existence of sources
.PHONY: xpr
xpr: $(VIVADO_PROJ_FILE)
$(VIVADO_PROJ_FILE): $(VIVADO_PROJ_RECIPE_FILE) | $(VIVADO_PROJ_RECIPE_SOURCES)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: create project                                                        $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
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
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: build block diagrams from TCL                                         $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build bd $1 $2 $(VIVADO_BD_SCP_MODE)
endef
$(foreach X,$(VIVADO_DSN_BD_TCL),$(eval $(call RR_VIVADO_BD,$(VIVADO_BD_PATH)/$(basename $(notdir $X))/$(basename $(notdir $X)).bd,$X)))

# BD hardware definitions depend on BD files and existence of project
define RR_VIVADO_BD_HWDEF
$1: $2 | $(VIVADO_PROJ_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: build block diagram hardware definitions                              $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build hwdef $2
endef
$(foreach X,$(VIVADO_DSN_BD_TCL),$(eval $(call RR_VIVADO_BD_HWDEF,$(VIVADO_BD_HWDEF_PATH)/$(basename $(notdir $X))/synth/$(basename $(notdir $X)).hwdef,$(VIVADO_BD_PATH)/$(basename $(notdir $X))/$(basename $(notdir $X)).bd)))

# hardware handoff (XSA) file
ifeq (microblaze,$(VITIS_ARCH))
# microblaze: depends on BD hwdef(s) and existence of project
$(VIVADO_XSA_FILE): $(VIVADO_DSN_BD_HWDEF) | $(VIVADO_PROJ_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: build hardware handoff (XSA) file                                     $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build xsa
else
# arm: depends on bit file
$(VIVADO_XSA_FILE): $(VIVADO_BIT_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: build hardware handoff (XSA) file (including bit file)                $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build xsa_bit
endif

# IP XCI files and simulation models depend on IP TCL scripts and existence of project
define RR_VIVADO_IP_XCI
$1 $(foreach X,$(VIVADO_SIM_IP_$(basename $(notdir $2))),$(VIVADO_SIM_IP_PATH)/$X) &: $2 | $(VIVADO_PROJ_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: build IP XCI file and simulation model(s)                             $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build ip $1 $2 $(foreach X,$(VIVADO_SIM_IP_$(basename $(notdir $2))),$(VIVADO_SIM_IP_PATH)/$X)
endef
$(foreach X,$(VIVADO_DSN_IP_TCL),$(eval $(call RR_VIVADO_IP_XCI,$(VIVADO_DSN_IP_PATH)/$(basename $(notdir $X))/$(basename $(notdir $X)).xci,$X)))

# synthesis file depends on design sources, relevant constraints and existence of project
$(VIVADO_SYNTH_FILE): $(VIVADO_DSN_IP_XCI) $(VIVADO_DSN_BD_HWDEF) $(VIVADO_DSN_VHDL) $(VIVADO_DSN_VHDL_2008) $(VIVADO_DSN_XDC_SYNTH) $(VIVADO_DSN_XDC) | $(VIVADO_PROJ_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: synthesis                                                             $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build synth $(VIVADO_JOBS)

# implementation and bit file generation depends on synthesis file, ELF file, relevant constraints and existence of project
# we also carry out simulation prep here so that project is left ready for interactive simulation
# NOTE: implementation changes BD timestamp which upsets dependancies, so we force BD modification time backwards
.PHONY: bit
bit: $(VIVADO_BIT_FILE)
tmp=touch --date=\"$$(date -r $2 -R) - 1 second\" $1 &&
$(VIVADO_BIT_FILE): $(VIVADO_SYNTH_FILE) $(VIVADO_DSN_ELF) $(VIVADO_SIM_ELF) $(VIVADO_DSN_XDC_IMPL) $(VIVADO_DSN_XDC) | $(VIVADO_PROJ_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: implementation and bitstream generation                               $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build impl_bit $(VIVADO_JOBS) $(if $(filter microblaze,$(VITIS_ARCH)),$(VIVADO_DSN_PROC_INST) $(VIVADO_DSN_PROC_REF) $(VIVADO_DSN_ELF))
	cp $@ $(MAKE_DIR)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: prepare for simulation                                                $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
ifeq (microblaze,$(VITIS_ARCH))
	cd $(VIVADO_DIR) && $(VIVADO_TCL) simprep \
		elf: $(VIVADO_DSN_PROC_INST) $(VIVADO_DSN_PROC_REF) $(VIVADO_SIM_ELF) \
		gen: $(VIVADO_SIM_GENERICS)
else
	cd $(VIVADO_DIR) && $(VIVADO_TCL) simprep \
		gen: $(VIVADO_SIM_GENERICS)
endif
	bash -c "$(call pairmap,tmp,$(VIVADO_DSN_BD),$(VIVADO_DSN_BD_HWDEF)) :"

# program FPGA
ifndef hw
ifdef HW
hw:=$(HW)
endif
endif
.PHONY: prog
prog: $(VIVADO_BIT_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: program FPGA                                                          $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) prog $< $(hw)

# update BD source TCL scripts from changed BD files
.PHONY: bd_update
define RR_VIVADO_UPDATE_BD
bd_update:: $1 $(VIVADO_PROJ_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vivado: update block diagram TCL                                              $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VIVADO_DIR) && $(VIVADO_TCL) build bd_tcl $2 $1
endef
$(foreach X,$(VIVADO_DSN_BD_TCL),$(eval $(call RR_VIVADO_UPDATE_BD,$(VIVADO_BD_PATH)/$(basename $(notdir $X))/$(basename $(notdir $X)).bd,$X)))

ifdef VITIS_APP

# project depends on XSA file (and existence of sources)
$(VITIS_PROJ_FILE): $(VIVADO_XSA_FILE) | $(VITIS_SRC)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vitis: create project                                                         $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	rm -rf $(VITIS_DIR)
	bash -c "mkdir -p $(VITIS_DIR)"
	cd $(VITIS_DIR) && $(VITIS_TCL) create $(VITIS_APP) $(VIVADO_XSA_FILE) $(VITIS_PROC) \
		src:     $(VITIS_SRC) \
		inc:     $(VITIS_INCLUDE) \
		inc_rls: $(VITIS_INCLUDE_RELEASE) \
		inc_dbg: $(VITIS_INCLUDE_DEBUG) \
		sym:     $(VITIS_SYMBOL) \
		sym_rls: $(VITIS_SYMBOL_RELEASE) \
		sym_dbg: $(VITIS_SYMBOL_DEBUG) \
		domain:  $(VITIS_DOMAIN) \
		bsp_lib: $(VITIS_BSP_LIB) \
		bsp_cfg: $(VITIS_BSP_CFG)

# ELF files depend on XSA file, source and project
.PHONY: elf
elf: $(VITIS_ELF_RELEASE) $(VITIS_ELF_DEBUG)
$(VITIS_ELF_RELEASE) : $(VIVADO_XSA_FILE) $(VITIS_SRC) $(VITIS_SRC_RELEASE) | $(VITIS_PROJ_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vitis: build release binary                                                   $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VITIS_DIR) && $(VITIS_TCL) build Release
$(VITIS_ELF_DEBUG) : $(VIVADO_XSA_FILE) $(VITIS_SRC) $(VITIS_SRC_DEBUG) | $(VITIS_PROJ_FILE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vitis: build debug binary                                                     $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VITIS_DIR) && $(VITIS_TCL) build Debug

# run depends on bit file, fsbl ELF, hw init TCL, release ELF
.PHONY: run
run:: $(VIVADO_BIT_FILE) $(VITIS_ELF_FSBL) $(VITIS_HW_INIT_TCL) $(VITIS_ELF_RELEASE)
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU) Vitis: program FPGA and run application via JTAG                              $(COL_RST)'"
	@bash -c "echo -e '$(COL_BG_WHT)$(COL_FG_BLU)-------------------------------------------------------------------------------$(COL_RST)'"
	cd $(VITIS_DIR) && $(VITIS_TCL) run $^

endif

endif

#-------------------------------------------------------------------------------
# Intel/Altera Quartus

else ifneq (,$(filter quartus,$(FPGA_TOOL)))
QUARTUS_TARGETS:=all qpf map fit sof rbf prog
ifneq (,$(filter $(QUARTUS_TARGETS),$(MAKECMDGOALS)))

quartus: sof rbf

# can't use the name of a phony target as a directory name, so prefix with .
QUARTUS_DIR?=.quartus

QUARTUS_PART?=$(FPGA_DEVICE)

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

endif

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

# defaults
RADIANT_PROJ?=fpga
RADIANT_CORES?=$(shell expr $(CPU_CORES) / 2)
RADIANT_DEV_ARCH?=$(FPGA_FAMILY)
RADIANT_DEV?=$(FPGA_DEVICE)
RADIANT_DEV_BASE?=$(word 1,$(subst -, ,$(RADIANT_DEV)))
RADIANT_DEV_PKG?=$(shell echo $(RADIANT_DEV)| grep -Po "(?<=-)(.+\d+)")
ifeq (ICE40UP,$(shell echo $(RADIANT_DEV_ARCH)| tr '[:lower:]' '[:upper:]'))
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
RADIANT_TARGETS:=all bin nvcm
ifneq (,$(filter $(RADIANT_TARGETS),$(MAKECMDGOALS)))

radiant_cmd: bin nvcm

# executables
RADIANT_SYNTHESIS:=synthesis
RADIANT_POSTSYN:=postsyn
RADIANT_MAP:=map
RADIANT_PAR:=par
RADIANT_BITGEN:=bitgen

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
	cd $(RADIANT_CMD_DIR) && $(RADIANT_SYNTHESIS) \
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
	cd $(RADIANT_CMD_DIR) && $(RADIANT_POSTSYN) \
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
	cd $(RADIANT_CMD_DIR) && $(RADIANT_MAP) \
		$(RADIANT_POSTSYN_UDB) \
		$(RADIANT_PDC) \
		-o $(notdir $@) \
		-mp $(basename $(RADIANT_MAP_UDB)).mrp \
		-xref_sig \
		-xref_sym

$(RADIANT_CMD_DIR)/$(RADIANT_PAR_UDB): $(RADIANT_CMD_DIR)/$(RADIANT_MAP_UDB) $(RADIANT_PDC)
	cd $(RADIANT_CMD_DIR) && $(RADIANT_PAR) \
		-w \
		-n 1 \
		-t 1 \
		-stopzero \
		-cores $(RADIANT_CORES) \
		$(RADIANT_MAP_UDB) \
		$(RADIANT_PAR_UDB) \
		$(RADIANT_PDC)

$(RADIANT_BIN): $(RADIANT_CMD_DIR)/$(RADIANT_PAR_UDB)
	cd $(RADIANT_CMD_DIR) && $(RADIANT_BITGEN) -w $(notdir $<) $(basename $@) && mv $@ ..

$(RADIANT_NVCM): $(RADIANT_CMD_DIR)/$(RADIANT_PAR_UDB)
	cd $(RADIANT_CMD_DIR) && $(RADIANT_BITGEN) -w -nvcm -nvcmsecurity $(notdir $<) $(basename $@) && mv $@ ..

.PHONY: bin
bin: $(RADIANT_BIN)

.PHONY: nvcm
nvcm: $(RADIANT_NVCM)

endif

#...............................................................................
# IDE flow

else ifneq (,$(filter radiant_ide,$(FPGA_TOOL)))
RADIANT_TARGETS:=all bin nvcm
ifneq (,$(filter $(RADIANT_TARGETS),$(MAKECMDGOALS)))

.PHONY: bin nvcm
radiant_ide: bin nvcm

ifeq ($(OS),Windows_NT)
RADIANT_EXE:=$(LATTICE_RADIANT)/bin/nt64/pnmainc.exe
else
RADIANT_EXE:=radiantc
endif
RADIANT_TCL:=$(RADIANT_EXE) $(MAKE_FPGA_TCL) radiant
#RADIANT_VER:=$(shell $(RADIANT_TCL) script sys_install_version)
#$(call check_shell_status,Could not set RADIANT_VER)
RADIANT_SYNTH?=lse

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

endif

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

# defaults
SIM_WORK?=work
SIM_LIB?=$(SIM_WORK)
SIM_SRC.$(SIM_WORK)?=$(SIM_SRC)

ifneq (,$(filter $(SUPPORTED_SIMULATOR),$(MAKECMDGOALS)))

# default to all
SIMULATOR?=$(SUPPORTED_SIMULATOR)

# single run: SIM_RUN=top[,generics]
# multiple runs: SIM_RUN=name1,top1[,generics1] name2,top2[,generics2] ...
SIM_RUNX=$(if $(word 2,$(SIM_RUN)),$(SIM_RUN),$(if $(word 3,$(subst $(COMMA),$(SPACE),$(SIM_RUN))),$(SIM_RUN),$(if $(word 2,$(subst $(COMMA),$(SPACE),$(SIM_RUN))),$(if $(findstring =,$(word 2,$(subst $(COMMA),$(SPACE),$(SIM_RUN)))),sim$(COMMA)),sim,)$(SIM_RUN)))

# recursively compile lib sources:
# $1 = touch dir e.g. $(GHDL_DIR)/.touch
# $2 = simulator
# $3 = root name of source list
# $4 = list of libs, last is working, others are deps
# $5 = list of sources, last is to be compiled, others are deps
define sim_com_lib
$(if $(word 2,$5),$(eval $(call sim_com_lib,$1,$2,$3,$4,$(call chop,$5))))
$(eval $(call $2_com,$1/$(call last,$4)/$(notdir $(call last,$5)).com,$(call last,$4),$(call last,$5),$(addprefix $1/$(call last,$4)/,$(addsuffix .com,$(notdir $(call chop,$5)))) $(foreach l,$(call chop,$4),$1/$l)))
endef

# recursively compile all libs:
# $1 = touch dir e.g. $(GHDL_DIR)/.touch
# $2 = simulator e.g. ghdl
# $3 = root name of source list e.g. GHDL_SRC
# $4 = list of libraries
define sim_com_all
$(if $(word 2,$4),$(eval $(call sim_com_all,$1,$2,$3,$(call chop,$4))))
$1/$(call last,$4)/.:
	bash -c "mkdir -p $$@"
$(eval $(call sim_com_lib,$1,$2,$3,$4,$($3.$(call last,$4))))
endef

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
SIM_DIR:=$(MAKE_DIR)/$(GHDL_DIR)
GHDL?=ghdl

GHDL_WORK?=$(SIM_WORK)
GHDL_LIB?=$(SIM_LIB)
$(foreach l,$(GHDL_LIB),$(eval GHDL_SRC.$l?=$(SIM_SRC.$l)))
GHDL_TOUCH_DIR:=$(GHDL_DIR)/.touch
GHDL_PREFIX?=$(dir $(shell which $(GHDL)))/..
ifeq ($(OS),Windows_NT)
GHDL_PREFIX:=$(shell cygpath -m $(GHDL_PREFIX))
endif

GHDL_AOPTS+=--std=08 -fsynopsys -frelaxed -Wno-hide -Wno-shared $(addprefix -P$(GHDL_PREFIX)/lib/ghdl/vendors/,$(GHDL_VENDOR_LIBS))
GHDL_EOPTS+=--std=08 -fsynopsys -frelaxed $(addprefix -P$(GHDL_PREFIX)/lib/ghdl/vendors/,$(GHDL_VENDOR_LIBS))
GHDL_ROPTS+=--max-stack-alloc=0 --ieee-asserts=disable

# $1 = output touch file
# $2 = work library
# $3 = source file
# $4 = dependencies (touch files)
define ghdl_com
$1: $3 $4 | $(dir $1).
	cd $$(GHDL_DIR) && $$(GHDL) -a --work=$2 $$(GHDL_AOPTS) $$<
	@touch $$@ $$(dir $$@).
sim:: $1
endef

define ghdl_run

sim:: force
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
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
		$$(if $$(filter gtkwave ghw,$$(MAKECMDGOALS)),--wave=$$(word 1,$1).ghw) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  finish at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------

sim:: $(GHDL_TOUCH_RUN)

$(GHDL_DIR)/$(word 1,$1).ghw: ghdl

gtkwave:: $(GHDL_DIR)/$(word 1,$1).ghw
ifeq ($(OS),Windows_NT)
	bash -c "cmd.exe /C start gtkwave $(GHDL_DIR)/$(word 1,$1).ghw"
else
	gtkwave $(GHDL_DIR)/$(word 1,$1).ghw
endif

endef

$(GHDL_DIR):
	bash -c "mkdir -p $(GHDL_DIR)"

$(eval $(call sim_com_all,$(GHDL_TOUCH_DIR),ghdl,GHDL_SRC,$(GHDL_LIB)))
$(foreach r,$(SIM_RUNX),$(eval $(call ghdl_run,$(subst $(COMMA),$(SPACE),$r))))

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
SIM_DIR:=$(MAKE_DIR)/$(NVC_DIR)
NVC?=nvc

NVC_LIB?=$(SIM_LIB)
$(foreach l,$(NVC_LIB),$(eval NVC_SRC.$l?=$(SIM_SRC.$l)))
NVC_TOUCH_DIR:=$(NVC_DIR)/.touch

NVC_GOPTS+=--std=2008 -L.
NVC_AOPTS+=--relaxed
NVC_EOPTS+=
NVC_ROPTS+=--ieee-warnings=off

# $1 = output touch file
# $2 = work library
# $3 = source file
# $4 = dependencies (touch files)
define nvc_com
$1: $3 $4 | $(dir $1).
	cd $$(NVC_DIR) && $$(NVC) $$(NVC_GOPTS) --work=$2 -a $$(NVC_AOPTS) $$<
	@touch $$@ $$(dir $$@).
sim:: $1
endef

define nvc_run

sim:: force
	cd $$(NVC_DIR) && $$(NVC) \
		$$(NVC_GOPTS) \
		--work=$$(SIM_WORK) \
		-e $$(word 2,$1) \
		$$(NVC_EOPTS) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  start at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------
	cd $$(NVC_DIR) && $$(NVC) \
		$$(NVC_GOPTS) \
		--work=$$(SIM_WORK) \
		-r $$(word 2,$1) \
		$$(NVC_ROPTS) \
		$$(if $$(filter gtkwave fst,$$(MAKECMDGOALS)),--format=fst --wave=$$(word 1,$1).fst --gtkw=$$(word 1,$1).gtkw)
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  finish at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------

$(NVC_DIR)/$(word 1,$1).fst $(NVC_DIR)/$(word 1,$1).gtkw: nvc

gtkwave:: $(NVC_DIR)/$(word 1,$1).fst $(NVC_DIR)/$(word 1,$1).gtkw
ifeq ($(OS),Windows_NT)
	bash -c "cmd.exe /C start gtkwave $(NVC_DIR)/$(word 1,$1).fst $(NVC_DIR)/$(word 1,$1).gtkw"
else
	gtkwave $(NVC_DIR)/$(word 1,$1).fst $(NVC_DIR)/$(word 1,$1).gtkw &
endif

endef

$(NVC_DIR):
	bash -c "mkdir -p $(NVC_DIR)"

$(eval $(call sim_com_all,$(NVC_TOUCH_DIR),nvc,NVC_SRC,$(NVC_LIB)))
$(foreach r,$(SIM_RUNX),$(eval $(call nvc_run,$(subst $(COMMA),$(SPACE),$r))))

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
SIM_DIR:=$(MAKE_DIR)/$(VSIM_DIR)
VSIM_INI?=modelsim.ini
VSIM_DO?=vsim.do
VLIB?=vlib
VMAP?=vmap
VCOM?=vcom
VSIM?=vsim

ifdef VSIM_BIN_DIR
VSIM_BIN_PREFIX:=$(if $(VSIM_BIN_DIR),$(VSIM_BIN_DIR)/,)
ifeq ($(VLIB),$(notdir $(VLIB)))
VLIB:=$(if $(VSIM_BIN_DIR),$(VSIM_BIN_DIR)/,)$(VLIB)
endif
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
VSIM_TOUCH_DIR:=$(VSIM_DIR)/.touch

VCOM_OPTS+=-2008 -explicit -stats=none
VSIM_TCL+=set NumericStdNoWarnings 1; onfinish exit; run -all; exit
VSIM_OPTS+=-t ps -c -onfinish stop -do "$(VSIM_TCL)"

define vsim_lib
$(VSIM_DIR)/$1: | $(VSIM_DIR)/$(VSIM_INI)
	cd $$(VSIM_DIR) && vlib $1
	cd $$(VSIM_DIR) && $(VMAP) -modelsimini $(VSIM_INI) $1 $1
endef

# $1 = output touch file
# $2 = work library
# $3 = source file
# $4 = dependencies (touch files)
define vsim_com
$1: $3 $4 | $(dir $1). $(VSIM_DIR)/$2 $(VSIM_DIR)/$(VSIM_INI) $(VSIM_DIR)/$(VSIM_DO)
	cd $$(VSIM_DIR) && $$(VCOM) -modelsimini $(VSIM_INI) -work $2 $$(VCOM_OPTS) $$<
	@touch $$@ $$(dir $$@).
	$$(file >>$(VSIM_DIR)/$(VSIM_DO),vcom -modelsimini $(VSIM_INI) -work $1 $$(VCOM_OPTS) $$<)
sim:: $1
endef

define vsim_run

sim:: force | $(VSIM_DIR)/$(VSIM_INI)
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
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
	$$(file >>$(VSIM_DIR)/$(VSIM_DO),vsim \
		-modelsimini $(VSIM_INI) \
		-work $$(VSIM_WORK) \
		$$(if $$(filter vcd gtkwave,$$(MAKECMDGOALS)),-do "vcd file $$(word 1,$1).vcd; vcd add -r *") \
		$$(VSIM_OPTS) \
		$$(word 2,$1) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1))) \
	)
	@echo -------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
else
	@echo simulation run: $$(word 1,$1)  finish at: $(date +"%T.%2N")
endif
	@echo -------------------------------------------------------------------------------

$(VSIM_DIR)/$(word 1,$1).vcd: vsim

vcd:: $(VSIM_DIR)/$(word 1,$1).vcd

$(VSIM_DIR)/$(word 1,$1).gtkw: $(VSIM_DIR)/$(word 1,$1).vcd
	sh $(REPO_ROOT)/submodules/vcd2gtkw/vcd2gtkw.sh \
	$(VSIM_DIR)/$(word 1,$1).vcd \
	$(VSIM_DIR)/$(word 1,$1).gtkw

gtkwave:: $(VSIM_DIR)/$(word 1,$1).vcd $(VSIM_DIR)/$(word 1,$1).gtkw
ifeq ($(OS),Windows_NT)
	start cmd.exe /C \"gtkwave $(VSIM_DIR)/$(word 1,$1).vcd $(VSIM_DIR)/$(word 1,$1).gtkw\"
else
	gtkwave $(VSIM_DIR)/$(word 1,$1).vcd $(VSIM_DIR)/$(word 1,$1).gtkw &
endif

endef

$(VSIM_DIR):
	bash -c "mkdir -p $(VSIM_DIR)"

$(VSIM_DIR)/$(VSIM_INI): | $(VSIM_DIR)
	bash -c "cd $(VSIM_DIR) && $(VMAP) -c && [ -f $(VSIM_INI) ] || mv modelsim.ini $(VSIM_INI)"

$(VSIM_DIR)/$(VSIM_DO): | $(VSIM_DIR)
	$(file >$(VSIM_DIR)/$(VSIM_DO),# make-fpga)

$(foreach l,$(VSIM_LIB),$(eval $(call vsim_lib,$l)))
$(eval $(call sim_com_all,$(VSIM_TOUCH_DIR),vsim,VSIM_SRC,$(VSIM_LIB)))
$(foreach r,$(SIM_RUNX),$(eval $(call vsim_run,$(subst $(COMMA),$(SPACE),$r))))

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
SIM_DIR:=$(MAKE_DIR)/$(XSIM_CMD_DIR)
XVHDL?=xvhdl
XELAB?=xelab
XSIM?=xsim

XSIM_CMD_LIB?=$(SIM_LIB)
$(foreach l,$(XSIM_CMD_LIB),$(eval XSIM_CMD_SRC.$l?=$(SIM_SRC.$l)))
XSIM_CMD_TOUCH_DIR:=$(XSIM_CMD_DIR)/.touch

XVHDL_OPTS+=-2008 -relax
XELAB_OPTS+=-debug typical -O2 -relax
XSIM_OPTS+=-onerror quit -onfinish quit

ifeq ($(OS),Windows_NT)

# $1 = output touch file
# $2 = work library
# $3 = source file
# $4 = dependencies (touch files)
define xsim_cmd_com
$1: $3 $4 | $(dir $1).
	bash -c "cd $$(XSIM_CMD_DIR) && cmd.exe /C \"$(XVHDL).bat $$(XVHDL_OPTS) -work $2 $(shell cygpath -w $3)\""
	@touch $$@ $$(dir $$@).
sim:: $1
endef

define xsim_cmd_run

sim:: $(XSIM_CMD_TOUCH_COM)
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
	bash -c "cd $$(XSIM_CMD_DIR) && cmd.exe /C $$(word 1,$1)_elab.bat"
	@echo -------------------------------------------------------------------------------
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
	@echo -------------------------------------------------------------------------------
	bash -c "cd $$(XSIM_CMD_DIR) && cmd.exe /C $$(word 1,$1)_sim.bat"
	@echo -------------------------------------------------------------------------------
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
	@echo -------------------------------------------------------------------------------

sim:: $(XSIM_CMD_TOUCH_RUN)

$(XSIM_CMD_DIR)/$(word 1,$1).vcd: $(XSIM_CMD_TOUCH_RUN)

vcd:: $(XSIM_CMD_DIR)/$(word 1,$1).vcd

$(XSIM_CMD_DIR)/$(word 1,$1).gtkw: $(XSIM_CMD_DIR)/$(word 1,$1).vcd
	sh $(REPO_ROOT)/submodules/vcd2gtkw/vcd2gtkw.sh \
	$(XSIM_CMD_DIR)/$(word 1,$1).vcd \
	$(XSIM_CMD_DIR)/$(word 1,$1).gtkw

gtkwave:: $(XSIM_CMD_DIR)/$(word 1,$1).vcd $(XSIM_CMD_DIR)/$(word 1,$1).gtkw
	start cmd.exe /C \"gtkwave $(XSIM_CMD_DIR)/$(word 1,$1).vcd $(XSIM_CMD_DIR)/$(word 1,$1).gtkw\"

endef

else

# $1 = output touch file
# $2 = work library
# $3 = source file
# $4 = dependencies (touch files)
define xsim_cmd_com
$1: $3 $4 | $(dir $1).
	cd $$(SIM_DIR) && $$(XVHDL) $$(XVHDL_OPTS) -work $2 $3
	@touch $$@ $$(dir $$@).
sim:: $1
endef

define xsim_cmd_run

$$(file >$$(XSIM_CMD_DIR)/$$(word 1,$1)_run.tcl, \
	$(if $(filter vcd gtkwave,$(MAKECMDGOALS)), \
	open_vcd $$(word 1,$1).vcd; log_vcd /*; run all; close_vcd; quit, \
	run all; quit \
	) \
)

sim:: force
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

$(XSIM_CMD_DIR):
	bash -c "mkdir -p $(XSIM_CMD_DIR)"

$(eval $(call sim_com_all,$(XSIM_CMD_TOUCH_DIR),xsim_cmd,XSIM_CMD_SRC,$(XSIM_CMD_LIB)))
$(foreach r,$(SIM_RUNX),$(eval $(call xsim_cmd_run,$(subst $(COMMA),$(SPACE),$r))))

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
SIM_DIR:=$(MAKE_DIR)/$(XSIM_IDE_DIR)

XSIM_IDE_LIB?=$(SIM_LIB)
$(foreach l,$(XSIM_IDE_LIB),$(eval XSIM_IDE_SRC.$l?=$(SIM_SRC.$l)))

VIVADO_PROJ?=xsim
VIVADO_PROJ_FILE?=$(XSIM_IDE_DIR)/$(VIVADO_PROJ).xpr

$(XSIM_IDE_DIR):
	bash -c "mkdir -p $(XSIM_IDE_DIR)"

# workaround for limited Windows command line length
create_project.tcl:=\
	create_project -force $(VIVADO_PROJ); \
	set_property target_language VHDL [get_projects $(VIVADO_PROJ)]; \
	add_files -norecurse -fileset [get_filesets sim_1] {$(foreach l,$(XSIM_IDE_LIB),$(XSIM_IDE_SRC.$l))}; \
	set_property file_type "VHDL 2008" [get_files -of_objects [get_filesets sim_1] {$(foreach l,$(SIM_LIB),$(SIM_SRC.$l))}]; \
	set_property used_in_synthesis false [get_files -of_objects [get_filesets sim_1] {$(foreach l,$(SIM_LIB),$(SIM_SRC.$l))}]; \
	set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]; \
	$(foreach l,$(XSIM_IDE_LIB),set_property library $l [get_files -of_objects [get_filesets sim_1] {$(XSIM_IDE_SRC.$l)}]; ) \
	exit

$(VIVADO_PROJ_FILE): $(foreach l,$(XSIM_IDE_LIB),$(XSIM_IDE_SRC.$l)) | $(XSIM_IDE_DIR)
	$(file >$(XSIM_IDE_DIR)/create_project.tcl,$(create_project.tcl))
	cd $(XSIM_IDE_DIR) && $(VIVADO_TCL) "source create_project.tcl"

define xsim_ide_run

sim:: | $(VIVADO_PROJ_FILE)
	@echo -------------------------------------------------------------------------------
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  start at: %time%\""
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
	@bash -c "cmd.exe /C \"@echo simulation run: $$(word 1,$1)  finish at: %time%\""
	@echo -------------------------------------------------------------------------------

endef

$(foreach r,$(SIM_RUNX),$(eval $(call xsim_ide_run,$(subst $(COMMA),$(SPACE),$r))))

ifneq (,$(word 2,$(SIM_RUN)))
# ensure that simulator is left set up for first run
sim::
	cd $(XSIM_IDE_DIR) && $(VIVADO_TCL) \
		"open_project $(VIVADO_PROJ); \
		set_property top $(word 2,$(subst $(COMMA),$(SPACE),$(word 1,$(SIM_RUNX)))) [get_filesets sim_1]; \
		set_property generic {$(subst $(SEMICOLON),$(SPACE),$(word 3,$(subst $(COMMA),$(SPACE),$(word 1,$(SIM_RUNX)))))} [get_filesets sim_1]; \
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
	bash -c "cmd.exe /C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
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
$(CONFIG_V4P_FILE): force | $(VSCODE_DIR)
	@echo $(CONFIG_V4P_LINES) | tr " " "\n" > $(CONFIG_V4P_FILE)
vscode: $(VSCODE_SYMLINKS) $(CONFIG_V4P_FILE)
	$(VSCODE) $(VSCODE_DIR)
