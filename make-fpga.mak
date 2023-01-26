################################################################################
# make-fpga.mak
# Support for using GNU make to drive FPGA builds and simulations.
################################################################################

# supported targets/goals
SUPPORTED_FPGA_TOOL:=vivado quartus radiant_cmd radiant_ide
SUPPORTED_SIMULATOR:=ghdl nvc vsim xsim_cmd xsim_ide
SUPPORTED_OTHER:=vcd gtkwave vscode clean

.PHONY: all sim clean force
.PHONY: $(SUPPORTED_FPGA_TOOL) $(SUPPORTED_SIMULATOR) $(SUPPORTED_OTHER)

ifeq (,$(MAKECMDGOALS))
ifdef FPGA_TOOL
ifneq (,$(filter-out $(SUPPORTED_FPGA_TOOL),$(FPGA_TOOL)))
$(error FPGA_TOOL specifies unsupported tool(s): $(filter-out $(SUPPORTED_FPGA_TOOLS),$(FPGA_TOOL)))
endif
all: $(FPGA_TOOL)
else
$(error FPGA_TOOL not defined, simulator not specified)
endif
endif

# FPGA build subdirectories
VIVADO_DIR?=vivado
QUARTUS_DIR?=quartus
RADIANT_CMD_DIR?=radiant_cmd
RADIANT_IDE_DIR?=radiant_ide

# simulation subdirectories
GHDL_DIR?=sim_ghdl
NVC_DIR?=sim_nvc
VSIM_DIR?=sim_vsim
XSIM_CMD_DIR?=sim_xsim_cmd
XSIM_IDE_DIR?=sim_xsim_ide

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
define check_exe
$(if $(filter $1,$(notdir $1)),$(if $(filter $1,$(notdir $(word 1,$(shell which $1 2>&1)))),,$(error $1: executable not found in path)),$(if $(filter $1,$(wildcard $1)),,$(error $1: file not found)))
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
MAKE_FPGA_DIR:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ifeq ($(OS),Windows_NT)
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

#-------------------------------------------------------------------------------
# AMD/Xilinx Vivado

ifneq (,$(filter vivado,$(FPGA_TOOL)))

VIVADO_GOALS:=bit xpr

.PHONY: bit
vivado: bit

$(call check_null_error,XILINX_VIVADO)
ifeq ($(OS),Windows_NT)
XILINX_VIVADO:=$(shell cygpath -m $(XILINX_VIVADO))
endif
VIVADO_EXE:=vivado
$(eval $(call check_exe,$(VIVADO_EXE)))
VIVADO_VER:=$(shell vivado -version | grep -Po '(?<=Vivado\sv)[^\s]+')

VIVADO_TCL:=vivado -mode tcl -notrace -nolog -nojournal -source $(MAKE_FPGA_TCL) -tclargs vivado script
VIVADO_PROJ?=fpga
VIVADO_XPR?=$(VIVADO_DIR)/$(VIVADO_PROJ).xpr

ifeq (,$(VIVADO_DSN_VHDL) $(VIVADO_DSN_VHDL_2008))
$(error Vivado: no VHDL sources)
endif
ifeq (,$(VIVADO_DSN_XDC) $(VIVADO_DSN_XDC_SYNTH) $(VIVADO_DSN_XDC_IMPL))
$(info WARNING: Vivado: no design constraints)
endif

VIVADO_XPR_RECIPE:=$(VIVADO_DIR)/$(VIVADO_PROJ)_recipe.txt
VIVADO_XPR_RECIPE_CONTENTS:=\
	$(VIVADO_LANG) \
	$(VIVADO_DSN_VHDL) \
	$(VIVADO_DSN_VHDL_2008) \
	$(VIVADO_DSN_IP_TCL) \
	$(VIVADO_DSN_BD_TCL) \
	$(VIVADO_DSN_XDC) \
	$(VIVADO_DSN_XDC_SYNTH) \
	$(VIVADO_DSN_XDC_IMPL)

$(VIVADO_DIR):
	bash -c "mkdir -p $(VIVADO_DIR)"

$(VIVADO_XPR_RECIPE): force | $(VIVADO_DIR)
	if [[ "$(VIVADO_XPR_RECIPE_CONTENTS)" != "$(<$(VIVADO_XPR_RECIPE))" ]]; then \
		echo "$(VIVADO_XPR_RECIPE_CONTENTS)" > $@; \
	fi

$(VIVADO_XPR): $(VIVADO_XPR_RECIPE) | $(VIVADO_DIR)
	cd $(VIVADO_DIR) && $(VIVADO_TCL) "\
		create_project -force $(VIVADO_PROJ); \
		set_property target_language VHDL [get_projects $(VIVADO_PROJ)]; \
		$(if $(FPGA_DEVICE), \
			set_property part $(FPGA_DEVICE) [current_project]; \
		,) \
		$(if $(VIVADO_DSN_VHDL), \
			add_files -norecurse -fileset [get_filesets sources_1] $(VIVADO_DSN_VHDL); \
		,) \
		$(if $(VIVADO_DSN_VHDL_2008), \
			add_files -norecurse -fileset [get_filesets sources_1] $(VIVADO_DSN_VHDL_2008); \
			set_property file_type \"VHDL 2008\" [get_files -of_objects [get_filesets sources_1] {$(VIVADO_DSN_VHDL_2008)}]; \
		,) \
		$(if $(VIVADO_DSN_XDC), \
			add_files -norecurse -fileset [get_filesets constrs_1] $(VIVADO_DSN_XDC); \
			set_property used_in_synthesis true [get_files -of_objects [get_filesets constrs_1] {$(VIVADO_DSN_XDC)}]; \
			set_property used_in_implementation true [get_files -of_objects [get_filesets constrs_1] {$(VIVADO_DSN_XDC)}]; \
		,) \
		$(if $(VIVADO_DSN_XDC_SYNTH), \
			add_files -norecurse -fileset [get_filesets constrs_1] $(VIVADO_DSN_XDC_SYNTH); \
			set_property used_in_synthesis true [get_files -of_objects [get_filesets constrs_1] {$(VIVADO_DSN_XDC_SYNTH)}]; \
			set_property used_in_implementation false [get_files -of_objects [get_filesets constrs_1] {$(VIVADO_DSN_XDC_SYNTH)}]; \
		,) \
		$(if $(VIVADO_DSN_XDC_IMPL), \
			add_files -norecurse -fileset [get_filesets constrs_1] $(VIVADO_DSN_XDC_IMPL); \
			set_property used_in_synthesis false [get_files -of_objects [get_filesets constrs_1] {$(VIVADO_DSN_XDC_IMPL)}]; \
			set_property used_in_implementation true [get_files -of_objects [get_filesets constrs_1] {$(VIVADO_DSN_XDC_IMPL)}]; \
		,) \
		$(if $(VIVADO_DSN_TOP), \
			set_property top $(VIVADO_DSN_TOP) [get_filesets sources_1]; \
		,) \
		$(if $(VIVADO_DSN_GEN), \
			set_property generic {$(VIVADO_DSN_GEN)} [get_filesets sources_1]; \
		,) \
		$(if $(VIVADO_SIM_VHDL), \
			add_files -norecurse -fileset [get_filesets sim_1] $(VIVADO_SIM_VHDL); \
		,) \
		$(if $(VIVADO_SIM_VHDL_2008), \
			add_files -norecurse -fileset [get_filesets sim_1] $(VIVADO_SIM_VHDL_2008); \
			set_property file_type \"VHDL 2008\" [get_files -of_objects [get_filesets sim_1] {$(VIVADO_SIM_VHDL_2008)}]; \
		,) \
		$(if $(VIVADO_SIM_TOP), \
			set_property top $(VIVADO_SIM_TOP) [get_filesets sim_1]; \
		,) \
		$(if $(VIVADO_SIM_GEN), \
			set_property generic {$(VIVADO_SIM_GEN)} [get_filesets sim_1]; \
		,) \
		exit \
	"
xpr: $(VIVADO_XPR)

#-------------------------------------------------------------------------------
# Intel/Altera Quartus

else ifneq (,$(filter quartus,$(FPGA_TOOL)))

.PHONY: sof rbf
quartus: sof rbf

# basic checks
$(call check_null_error,QUARTUS_ROOTDIR)
ifeq ($(OS),Windows_NT)
QUARTUS_ROOTDIR:=$(shell cygpath -m $(QUARTUS_ROOTDIR))
endif
QUARTUS_EXE:=vivado
$(eval $(call check_exe,$(QUARTUS_EXE)))
QUARTUS_VER:=$(shell quartus_sh --tcl_eval regexp {[\.0-9]+} $quartus(version) ver; puts $ver)

$(info Intel/Altera Quartus version $(QUARTUS_VER))

$(error Quartus support is missing)

#-------------------------------------------------------------------------------
# Lattice Radiant

else ifneq (,$(findstring radiant,$(FPGA_TOOL)))

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
$(eval $(call check_exe,$(RADIANT_EXE)))
RADIANT_TCL:=$(RADIANT_EXE) $(MAKE_FPGA_TCL) radiant
RADIANT_VER:=$(shell $(RADIANT_TCL) script sys_install_version)
$(call check_shell_status,Could not set RADIANT_VER)

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

# warnings
$(call check_null_warning,RADIANT_LDC)
$(call check_null_warning,RADIANT_PDC)

#...............................................................................
# command line flow

ifneq (,$(filter radiant_cmd,$(FPGA_TOOL)))

.PHONY: bin nvcm
radiant_cmd: bin nvcm

$(info Lattice Radiant version $(RADIANT_VER) - Command Line Flow)

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

bin: $(RADIANT_BIN)

nvcm: $(RADIANT_NVCM)

#...............................................................................
# IDE flow

else ifneq (,$(filter radiant_ide,$(FPGA_TOOL)))

.PHONY: bin nvcm
radiant_ide: bin nvcm

$(info Lattice Radiant version $(RADIANT_VER) - IDE Flow)

RADIANT_RDF?=$(RADIANT_PROJ).rdf
RADIANT_IMPL?=impl_1

$(RADIANT_IDE_DIR):
	bash -c "mkdir -p $(RADIANT_IDE_DIR)"

$(RADIANT_IDE_DIR)/$(RADIANT_RDF): (ALL MAKEFILES) | $(RADIANT_IDE_DIR)
	cd $(RADIANT_IDE_DIR) && \
	rm -f $(RADIANT_PROJ).rdf && \
	$(RADIANT_TCL) script \
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

$(error Lattice Radiant version $(RADIANT_VER) - unknown flow: $(FPGA_TOOL))

endif

################################################################################

else

ifdef FPGA_TOOL
$(error Unknown FPGA tool: $(FPGA_TOOL))
endif

endif

################################################################################
# simulation targets

SIM_DIR:=
SIM_WORK?=work

# single run: SIM_RUN=top[,generics]
# multiple runs: SIM_RUN=name1,top1[,generics1] name2,top2[generics2] ...
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

SIM_DIR+=$(GHDL_DIR)
GHDL?=ghdl
$(eval $(call check_exe,$(GHDL)))

GHDL_SRC?=$(SIM_SRC)
GHDL_WORK?=$(SIM_WORK)
GHDL_TOUCH_COM:=$(GHDL_DIR)/touch.com
GHDL_TOUCH_RUN:=$(GHDL_DIR)/touch.run
GHDL_PREFIX?=$(dir $(shell which $(GHDL)))/..
ifeq ($(OS),Windows_NT)
GHDL_PREFIX:=$(shell cygpath -m $(GHDL_PREFIX))
endif

GHDL_AOPTS+=--std=08 -fsynopsys -frelaxed -Wno-hide -Wno-shared $(addprefix -P$(GHDL_PREFIX)/lib/ghdl/vendors/,$(GHDL_LIBS))
GHDL_EOPTS+=--std=08 -fsynopsys -frelaxed $(addprefix -P$(GHDL_PREFIX)/lib/ghdl/vendors/,$(GHDL_LIBS))
GHDL_ROPTS+=--unbuffered --max-stack-alloc=0 --ieee-asserts=disable

define ghdl_com
$(GHDL_TOUCH_COM):: $1 | $(GHDL_DIR)
	cd $$(GHDL_DIR) && $$(GHDL) \
		-a \
		--work=$$(GHDL_WORK) \
		$$(GHDL_AOPTS) \
		$1
	touch $(GHDL_TOUCH_COM)
endef

define ghdl_run

$(GHDL_TOUCH_RUN):: $(GHDL_TOUCH_COM) | $(GHDL_DIR)
	cd $$(GHDL_DIR) && $$(GHDL) \
		--elab-run \
		--work=$$(GHDL_WORK) \
		$$(GHDL_EOPTS) \
		$$(word 2,$1) \
		$$(GHDL_ROPTS) \
		$$(if $$(filter vcd gtkwave,$$(MAKECMDGOALS)),--vcd=$$(word 1,$1).vcd) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
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
	start cmd.exe //C \"gtkwave $(GHDL_DIR)/$(word 1,$1).vcd $(GHDL_DIR)/$(word 1,$1).gtkw\"
else
	gtkwave $(GHDL_DIR)/$(word 1,$1).vcd $(GHDL_DIR)/$(word 1,$1).gtkw &
endif

endef

$(GHDL_DIR):
	bash -c "mkdir -p $(GHDL_DIR)"

$(foreach s,$(GHDL_SRC),$(eval $(call ghdl_com,$s)))
$(foreach r,$(SIM_RUN),$(eval $(call ghdl_run,$(subst $(COMMA),$(SPACE),$r))))

endif

#-------------------------------------------------------------------------------
# support for NVC

ifneq (,$(filter nvc,$(MAKECMDGOALS)))

ifeq (,$(filter nvc,$(SIMULATOR)))
$(error This makefile does not support NVC)
endif

nvc: sim

SIM_DIR+=$(NVC_DIR)
NVC?=nvc
$(eval $(call check_exe,$(NVC)))

NVC_SRC?=$(SIM_SRC)
NVC_WORK?=$(SIM_WORK)
NVC_TOUCH_COM:=$(NVC_DIR)/touch.com
NVC_TOUCH_RUN:=$(NVC_DIR)/touch.run

NVC_GOPTS+=--std=2008
NVC_AOPTS+=--relaxed
NVC_EOPTS+=
NVC_ROPTS+=--ieee-warnings=off

define nvc_com
$(NVC_TOUCH_COM):: $1 | $(NVC_DIR)
	cd $$(NVC_DIR) && $$(NVC) \
		$$(NVC_GOPTS) \
		--work=$$(SIM_WORK) \
		-a $$(NVC_AOPTS) \
		$1
	touch $(NVC_TOUCH_COM)
endef

define nvc_run

$(NVC_TOUCH_RUN):: $(NVC_TOUCH_COM) | $(NVC_DIR)
	cd $$(NVC_DIR) && $$(NVC) \
		$$(NVC_GOPTS) \
		--work=$$(SIM_WORK) \
		-e $$(word 2,$1) \
		$$(NVC_EOPTS) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
	cd $$(NVC_DIR) && $$(NVC) \
		$$(NVC_GOPTS) \
		--work=$$(SIM_WORK) \
		-r $$(word 2,$1) \
		$$(NVC_ROPTS) \
		$$(if $$(filter vcd gtkwave,$$(MAKECMDGOALS)),--format=vcd --wave=$$(word 1,$1).vcd)
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
	start cmd.exe //C \"gtkwave $(NVC_DIR)/$(word 1,$1).vcd $(NVC_DIR)/$(word 1,$1).gtkw\"
else
	gtkwave $(NVC_DIR)/$(word 1,$1).vcd $(NVC_DIR)/$(word 1,$1).gtkw &
endif

endef

$(NVC_DIR):
	bash -c "mkdir -p $(NVC_DIR)"

$(foreach s,$(NVC_SRC),$(eval $(call nvc_com,$s)))
$(foreach r,$(SIM_RUN),$(eval $(call nvc_run,$(subst $(COMMA),$(SPACE),$r))))

endif

#-------------------------------------------------------------------------------
# support for vsim (ModelSim/Questa/etc)

ifneq (,$(filter vsim,$(MAKECMDGOALS)))

ifeq (,$(filter vsim,$(SIMULATOR)))
$(error This makefile does not support vsim (ModelSim/Questa/etc))
endif

vsim: sim

SIM_DIR+=$(VSIM_DIR)
VSIM_INI?=modelsim.ini
VMAP?=vmap
VCOM?=vcom
VSIM?=vsim

ifdef VSIM_BIN_DIR
$(info VSIM_BIN_DIR=$(VSIM_BIN_DIR))
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
$(eval $(call check_exe,$(VMAP)))
$(eval $(call check_exe,$(VCOM)))
$(eval $(call check_exe,$(VSIM)))

VSIM_SRC?=$(SIM_SRC)
VSIM_WORK?=$(SIM_WORK)
VSIM_TOUCH_COM:=$(VSIM_DIR)/touch.com
VSIM_TOUCH_RUN:=$(VSIM_DIR)/touch.run

VCOM_OPTS+=-2008 -explicit -stats=none
VSIM_TCL+=set NumericStdNoWarnings 1; onfinish exit; run -all; exit
VSIM_OPTS+=-t ps -c -onfinish stop -do "$(VSIM_TCL)"

define vsim_com
$(VSIM_TOUCH_COM):: $1 | $(VSIM_DIR) $(VSIM_DIR)/$(VSIM_INI)
	cd $$(VSIM_DIR) && $$(VCOM) \
		-modelsimini $(VSIM_INI) \
		-work $$(VSIM_WORK) \
		$$(VCOM_OPTS) \
		$1
	touch $(VSIM_TOUCH_COM)
endef

define vsim_run

$(VSIM_TOUCH_RUN):: $(VSIM_TOUCH_COM) | $(VSIM_DIR) $(VSIM_DIR)/$(VSIM_INI)
	cd $$(VSIM_DIR) && $$(VSIM) \
		-modelsimini $(VSIM_INI) \
		-work $$(VSIM_WORK) \
		$$(if $$(filter vcd gtkwave,$$(MAKECMDGOALS)),-do "vcd file $$(word 1,$1).vcd; vcd add -r *") \
		$$(VSIM_OPTS) \
		$$(word 2,$1) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
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

$(foreach s,$(VSIM_SRC),$(eval $(call vsim_com,$s)))
$(foreach r,$(SIM_RUN),$(eval $(call vsim_run,$(subst $(COMMA),$(SPACE),$r))))

endif

#-------------------------------------------------------------------------------
# support for xsim (Vivado simulator)

ifneq (,$(filter xsim_cmd xsim_ide,$(MAKECMDGOALS)))

ifeq (,$(filter xsim,$(SIMULATOR)))
$(error This makefile does not support XSim)
endif

XSIM_SRC?=$(SIM_SRC)
XSIM_WORK?=$(SIM_WORK)

#...............................................................................
# command line flow

ifneq (,$(filter xsim_cmd,$(MAKECMDGOALS)))

xsim_cmd: sim

SIM_DIR+=$(XSIM_CMD_DIR)
XVHDL?=xvhdl
$(eval $(call check_exe,$(XVHDL)))
XELAB?=xelab
$(eval $(call check_exe,$(XELAB)))
XSIM?=xsim
$(eval $(call check_exe,$(XSIM)))

XSIM_CMD_TOUCH_COM:=$(XSIM_CMD_DIR)/touch.com
XSIM_CMD_TOUCH_RUN:=$(XSIM_CMD_DIR)/touch.run

XVHDL_OPTS+=-2008 -relax
XELAB_OPTS+=-debug typical -O2 -relax
XSIM_OPTS+=-onerror quit -onfinish quit

ifeq ($(OS),Windows_NT)

define xsim_cmd_com

$(XSIM_CMD_TOUCH_COM):: $1 | $(XSIM_CMD_DIR)
	cd $$(XSIM_CMD_DIR) && cmd.exe //C $(XVHDL).bat \
		$$(XVHDL_OPTS) \
		-work $$(SIM_WORK) \
		$1
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
	$$(file >$$(XSIM_CMD_DIR)/$$(word 1,$1)_run.bat, \
		$$(XELAB).bat \
			$$(XELAB_OPTS) \
			-L $$(SIM_WORK) \
			-top $$(word 2,$1) \
			-snapshot $$(word 2,$1)_$$(word 1,$1) \
			$$(addprefix -generic_top ",$$(addsuffix ",$$(subst ;, ,$$(word 3,$1)))) \
		&& \
		$$(XSIM).bat \
			$$(XSIM_OPTS) \
			-tclbatch $$(word 1,$1)_run.tcl \
			$$(word 2,$1)_$$(word 1,$1) \
	)
	cd $$(XSIM_CMD_DIR) && cmd.exe //C $$(word 1,$1)_run.bat
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
		-work $$(SIM_WORK) \
		$1
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
	cd $$(XSIM_CMD_DIR) && $$(XSIM) \
		$$(XSIM_OPTS) \
		-tclbatch $$(word 1,$1)_run.tcl \
		$$(word 2,$1)_$$(word 1,$1)
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

$(XSIM_CMD_DIR):
	bash -c "mkdir -p $(XSIM_CMD_DIR)"

$(foreach s,$(XSIM_SRC),$(eval $(call xsim_cmd_com,$s)))
$(foreach r,$(SIM_RUN),$(eval $(call xsim_cmd_run,$(subst $(COMMA),$(SPACE),$r))))

endif

#...............................................................................
# IDE flow

ifneq (,$(filter xsim_ide,$(MAKECMDGOALS)))

xsim_ide: sim

# basic checks
VIVADO_EXE:=vivado
$(eval $(call check_exe,$(VIVADO_EXE)))
VIVADO_TCL:=$(VIVADO_EXE) -mode tcl -notrace -nolog -nojournal -source $(MAKE_FPGA_TCL) -tclargs vivado script

SIM_DIR+=$(XSIM_IDE_DIR)

VIVADO_PROJ?=xsim
VIVADO_PROJ_FILE?=$(XSIM_IDE_DIR)/$(VIVADO_PROJ).xpr

$(XSIM_IDE_DIR):
	bash -c "mkdir -p $(XSIM_IDE_DIR)"

$(VIVADO_PROJ_FILE): $(XSIM_SRC) | $(XSIM_IDE_DIR)
	cd $(XSIM_IDE_DIR) && $(VIVADO_TCL) \
		"create_project -force $(VIVADO_PROJ); \
		set_property target_language VHDL [get_projects $(VIVADO_PROJ)]; \
		add_files -norecurse -fileset [get_filesets sim_1] $(XSIM_SRC); \
		set_property file_type \"VHDL 2008\" [get_files -of_objects [get_filesets sim_1] {$(XSIM_SRC)}]; \
		set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]; \
		exit"

define xsim_ide_run

sim:: | $(VIVADO_PROJ_FILE)
	cd $(XSIM_IDE_DIR) && $(VIVADO_TCL) \
		"open_project $(VIVADO_PROJ); \
		set_property top $$(word 2,$1) [get_filesets sim_1]; \
		$(if $(word 3,$1),set_property generic {$(subst $(SEMICOLON),$(SPACE),$(word 3,$1))} [get_filesets sim_1];) \
		puts \"Run: $$(word 1,$1)\"; \
		launch_simulation; \
		run all; \
		exit"

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
$(VSCODE_DIR):
	mkdir $(VSCODE_DIR)
VSCODE_SRC+=$(foreach x,$(V4P_LIB_SRC),$(word 2,$(subst ;, ,$x)))
VSCODE_SYMLINKS:=$(addprefix $(VSCODE_DIR)/,$(notdir $(VSCODE_SRC)))
define RR_VSCODE_SYMLINK
ifeq ($(OS),Windows_NT)
$(VSCODE_DIR)/$(notdir $1): $1 | $(VSCODE_DIR)
	cmd.exe //C "mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)"
else
$(VSCODE_DIR)/$(notdir $1): $1
	ln $$< $$@
endif
endef
$(foreach s,$(VSCODE_SRC),$(eval $(call RR_VSCODE_SYMLINK,$s)))
CONFIG_V4P_FILE:=$(VSCODE_DIR)/config.v4p
CONFIG_V4P_LINES:= \
	[libraries] \
	$(foreach x,$(V4P_LIB_SRC),$(notdir $(word 2,$(subst ;, ,$x)))=$(word 1,$(subst ;, ,$x))) \
	*.vh*=work \
	[settings] \
	V4p.Settings.Basics.TopLevelEntities=$(V4P_TOP)
FORCE:
$(CONFIG_V4P_FILE): FORCE
	l=( $(CONFIG_V4P_LINES) ); printf "%s\n" "$${l[@]}" > $(CONFIG_V4P_FILE)
vscode: $(VSCODE_SYMLINKS) $(CONFIG_V4P_FILE) | $(VSCODE_DIR)
	$(VSCODE) $(VSCODE_DIR)

#################################################################################
# cleanup

clean:
	find . -type f -not \( -name 'makefile' -or -name '.gitignore' \) -delete
	rm -rf */
	rm -rf .*/
