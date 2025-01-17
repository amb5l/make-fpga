################################################################################
# vsim.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
# VSIM_VHDL_LRM  VHDL LRM if not specified per source file (default: 2008)
# VSIM_SRC       sources to compile
#                  path/file<=lib><;language> <path/file<=lib><;language>> ...
# VSIM_RUN       list of simulation runs, each as follows:
#                  name=<lib:>:unit<;generic=value<,generic=value...>>
#                For a single run, name= may be omitted and defaults to 'sim='
# VCOM_OPTS      compilation options
# VSIM_EDIT      Set to 0 to disable Visual Studio Code 'edit' goal.
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

# defaults
.PHONY: vsim_default vsim_force
vsim_default: vsim
vsim_force:
VLIB?=vlib
VMAP?=vmap
VCOM?=vcom
VSIM?=vsim
VSIM_DIR?=sim_vsim
VSIM_INI?=modelsim.ini
VCOM_DO?=vcom.do
VSIM_DO?=vsim.do
VSIM_WORK?=work
VSIM_VHDL_LRM?=2008
VCOM_OPTS?=-explicit -stats=none
VSIM_TCL?=set NumericStdNoWarnings 1
VSIM_TCL_BAT?=$(if $(VSIM_TCL),$(VSIM_TCL); )onfinish exit; run -all; exit
VSIM_TCL_DO?=$(if $(VSIM_TCL),$(VSIM_TCL); )onfinish stop; run -all

# checks
$(if $(strip $(VSIM_SRC)),,$(error VSIM_SRC not defined))
$(if $(strip $(VSIM_RUN)),,$(error VSIM_RUN not defined))
ifneq (1,$(words $(VSIM_RUN)))
$(foreach r,$(VSIM_RUN),$(if $(findstring =,$(word 1,$(subst ;, ,$r))),,$(error Multiple simulation runs must be named)))
else
$(if $(findstring =,$(word 1,$(subst ;, ,$(VSIM_RUN)))),,$(eval VSIM_RUN=sim=$(value VSIM_RUN)))
endif
$(if $(filter 1987 1993 2002 2008,$(VSIM_VHDL_LRM)),,$(error VSIM_VHDL_LRM value is unsupported: $(VSIM_VHDL_LRM)))
$(foreach s,$(VSIM_SRC),$(if $(filter 1987 1993 2002 2008,$(call get_src_lrm,$s,$(VSIM_VHDL_LRM))),,$(error source file LRM is unsupported: $s)))

# compilation dependencies enforce compilation order
dep:=$(firstword $(VSIM_SRC))<= $(if $(word 2,$(VSIM_SRC)),$(call pairmap,src_dep,$(call rest,$(VSIM_SRC)),$(call chop,$(VSIM_SRC))),)

# extract libraries from sources
VSIM_LIB=$(call nodup,$(call get_src_lib,$(VSIM_SRC),$(VSIM_WORK)))

################################################################################
# rules and recipes

# main directory
$(VSIM_DIR):
	@$(MKDIR) -p $@

# modelsim.ini
$(VSIM_DIR)/$(VSIM_INI): | $(VSIM_DIR)
	@cd $(VSIM_DIR) && $(VMAP) -c && [ -f $(VSIM_INI) ] || mv modelsim.ini $(VSIM_INI)

# libraries
define vsim_lib
$(VSIM_DIR)/$1: | $(VSIM_DIR)/$(VSIM_INI)
	@cd $$(VSIM_DIR) && vlib $1
	@cd $$(VSIM_DIR) && $(VMAP) -modelsimini $(VSIM_INI) $1 $1
endef
$(foreach l,$(VSIM_LIB),$(eval $(call vsim_lib,$l)))

# touch directories to track compilation
define rr_touchdir
$(VSIM_DIR)/$1/.touch:
	@$(MKDIR) -p $$@
endef
$(foreach l,$(VSIM_LIB),$(eval $(call rr_touchdir,$l)))

# compilation
# $1 = source path/file
# $2 = source library
# $3 = LRM
# $4 = dependency source path/file
# $5 = dependency source library
define rr_com
$(VSIM_DIR)/$(strip $2)/.touch/$(notdir $(strip $1)): $(strip $1) $(if $(strip $4),$(VSIM_DIR)/$(strip $5)/.touch/$(notdir $(strip $4))) $(if $(filter dev,$(MAKECMDGOALS)),,$(MAKEFILE_LIST)) | $(VSIM_DIR)/$(strip $2) $(VSIM_DIR)/$(strip $2)/.touch
	@cd $(VSIM_DIR) && $(VCOM) \
		-modelsimini $(VSIM_INI) \
		-work $(strip $2) \
		-$(strip $3) \
		$(VCOM_OPTS) \
		$$<
	@touch $$@
endef
$(foreach d,$(dep),$(eval $(call rr_com, \
	$(call get_src_file, $(word 1,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 1,$(subst <=, ,$d)),$(VSIM_WORK)), \
	$(call get_src_lrm,  $(word 1,$(subst <=, ,$d)),$(VSIM_VHDL_LRM)), \
	$(call get_src_file, $(word 2,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 2,$(subst <=, ,$d)),$(VSIM_WORK))  \
)))

# simulation run
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
.PHONY: vsim
define rr_run
.PHONY: vsim.$(strip $1)
vsim.$(strip $1):: $(VSIM_DIR)/$(call get_src_lib,$(lastword $(VSIM_SRC)),$(VSIM_WORK))/.touch/$(notdir $(call get_src_file,$(lastword $(VSIM_SRC))))
	$(call banner,vsim: simulation run = $1)
	@cd $(VSIM_DIR) && $(VSIM) \
		-t ps \
		-modelsimini $(VSIM_INI) \
		-work $2 \
		 -c \
		 $(VSIM_OPTS) \
		-do "$(VSIM_TCL_BAT)" \
		$3 \
		$(addprefix -g,$(strip $4))
vsim:: vsim.$(strip $1)
endef
$(foreach r,$(VSIM_RUN),$(eval $(call rr_run, \
	$(call get_run_name, $r), \
	$(call get_run_lib,  $r, $(VSIM_WORK)), \
	$(call get_run_unit, $r), \
	$(call get_run_gen,  $r)  \
)))

# compilation do file
# $1 = source path/file
# $2 = source library
# $3 = LRM
define rr_do_com
vcom -modelsimini $(VSIM_INI) -work $(strip $2) -$(strip $3) $(VCOM_OPTS) $(strip $1)
endef

# simulation run do file
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
define rr_do_run
proc run_$1 {} { vsim -t ps -modelsimini $(VSIM_INI) -work $(VSIM_WORK) $(VSIM_OPTS) -do "$(VSIM_TCL_DO)" $3 $(addprefix -g,$4) }
endef

.PHONY: vsim_do
$(VSIM_DIR)/$(VCOM_DO): vsim_force | $(VSIM_DIR)
	@printf "# generated by vsim.mak" > $@
	@printf "$(foreach d,$(dep),\n$(call rr_do_com,$(call get_src_file,$(word 1,$(subst <=, ,$d))),$(call get_src_lib,$(word 1,$(subst <=, ,$d)),$(VSIM_WORK)),$(call get_src_lrm,$(word 1,$(subst <=, ,$d)),$(VSIM_VHDL_LRM))))\n" >> $@
$(VSIM_DIR)/$(VSIM_DO): vsim_force | $(VSIM_DIR)
	@printf "# generated by vsim.mak" > $@
	@printf "$(subst ",\",$(foreach r,$(VSIM_RUN),\n$(call rr_do_run,$(call get_run_name,$r),$(call get_run_lib,$r),$(call get_run_unit,$r),$(call get_run_gen,$r)))\n)" >> $@
vsim_do: $(VSIM_DIR)/$(VCOM_DO) $(VSIM_DIR)/$(VSIM_DO)
vsim_gui: $(VSIM_DIR)/$(VCOM_DO) $(VSIM_DIR)/$(VSIM_DO) $(addprefix $(VSIM_DIR)/,$(VSIM_LIB))
ifeq ($(OS),Windows_NT)
	@cd $(VSIM_DIR) && start $(VSIM) -gui -do $(VCOM_DO) -do $(VSIM_DO)
else
	@cd $(VSIM_DIR) && $(VSIM) -gui -do $(VCOM_DO) -do $(VSIM_DO) &
endif

################################################################################
# Visual Studio Code

ifneq (0,$(VSIM_EDIT))

VSIM_EDIT_DIR=edit/vsim
VSIM_EDIT_TOP=$(call nodup,$(call get_run_unit,$(VSIM_RUN)))
VSIM_EDIT_SRC=$(VSIM_SRC)
VSIM_EDIT_LIB=$(call nodup,$(call get_src_lib,$(VSIM_EDIT_SRC),$(VSIM_WORK)))
$(foreach l,$(VSIM_EDIT_LIB), \
	$(foreach s,$(VSIM_EDIT_SRC), \
		$(if $(filter $l,$(call get_src_lib,$s,$(VSIM_WORK))), \
			$(eval VSIM_EDIT_SRC.$l+=$(call get_src_file,$s)) \
		) \
	) \
)

# workspace directory
$(VSIM_EDIT_DIR):
	@$(MKDIR) -p $@

# library directory(s) containing symbolic link(s) to source(s)
$(foreach l,$(VSIM_EDIT_LIB),$(eval $l: $(addprefix $$(VSIM_EDIT_DIR)/$l/,$(notdir $(VSIM_EDIT_SRC.$l)))))

# symbolic links to source files
define rr_srclink
$$(VSIM_EDIT_DIR)/$1/$(notdir $2): $2
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach l,$(VSIM_EDIT_LIB),$(foreach s,$(VSIM_EDIT_SRC.$l),$(eval $(call rr_srclink,$l,$s))))

# symbolic links to auxilliary text files
define rr_auxlink
$$(VSIM_EDIT_DIR)/$(notdir $1): $1
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach a,$(VSIM_EDIT_AUX),$(eval $(call rr_auxlink,$a)))

# V4P configuration file
$(VSIM_EDIT_DIR)/config.v4p: vsim_force $(VSIM_EDIT_LIB)
	$(file >$@,[libraries])
	$(foreach l,$(VSIM_EDIT_LIB),$(foreach s,$(VSIM_EDIT_SRC.$l),$(file >>$@,$l/$(notdir $s)=$l)))
	$(file >>$@,[settings])
	$(file >>$@,V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(strip $(VSIM_EDIT_TOP))))

edit:: $(VSIM_EDIT_DIR)/config.v4p $(addprefix $(VSIM_EDIT_DIR)/,$(VSIM_EDIT_LIB)) $(addprefix $(VSIM_EDIT_DIR)/,$(notdir $(VSIM_EDIT_AUX)))
ifeq ($(OS),Windows_NT)
	@cd $(VSIM_EDIT_DIR) && start code .
else
	@cd $(VSIM_EDIT_DIR) && code . &
endif

endif

################################################################################

help::
	$(call print_col,col_fi_cyn,  vsim.mak)
	$(call print_col,col_fi_wht,  Support for simulation with ModelSim, Questa, etc.)
	$(call print_col,col_fg_wht, )
	$(call print_col,col_fg_wht,    Goals:)
	$(call print_col,col_fi_grn,      vsim       $(col_fg_wht)- perform all simulation runs)
	$(call print_col,col_fi_grn,      vsim.<run> $(col_fg_wht)- perform specified simulation run)
	$(call print_col,col_fi_grn,      vsim_do    $(col_fg_wht)- create .do files for compilation and simulation)
	$(call print_col,col_fi_grn,      vsim_gui   $(col_fg_wht)- create .do files, open GUI for interactive simulation)
	$(call print_col,col_fi_grn,      edit       $(col_fg_wht)- create and open Visual Studio Code workspace directory)
	$(call print_col,col_fg_wht, )

################################################################################

clean::
	@rm -rf $(VSIM_DIR)
