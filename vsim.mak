################################################################################
# vsim.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
# name
# VSIM_VHDL_LRM       VHDL LRM if not specified per source file (default: 2008)
# VSIM_SRC       sources to compile
#				   path/file<=lib><;language> <path/file<=lib><;language>> ...
# VSIM_RUN       list of simulation runs, each as follows:
#                 name=lib:unit<;generic=value<,generic=value...>>
#                 For a single run, name= may be omitted and defaults to 'sim='
# VSIM_G_OPTS
# VSIM_A_OPTS
# VSIM_E_OPTS
# VSIM_R_OPTS
################################################################################

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

# definitions and functions
comma:=,
rest         = $(wordlist 2,$(words $1),$1)
chop         = $(wordlist 1,$(words $(call rest,$1)),$1)
src_dep      = $1<=$2
pairmap      = $(and $(strip $2),$(strip $3),$(call $1,$(firstword $2),$(firstword $3)) $(call pairmap,$1,$(call rest,$2),$(call rest,$3)))
nodup        = $(if $1,$(firstword $1) $(call nodup,$(filter-out $(firstword $1),$1)))
get_src_file = $(foreach x,$1,$(word 1,$(subst =, ,$(word 1,$(subst ;, ,$x)))))
get_src_lib  = $(foreach x,$1,$(if $(word 1,$(subst ;, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$x)))))),$(word 1,$(subst ;, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$x)))))),$(VSIM_WORK)))
get_src_lang = $(word 1,$(subst =, ,$(word 2,$(subst ;, ,$1))))
get_src_lrm  = $(if $(findstring VHDL-,$(call get_src_lang,$1)),$(word 2,$(subst -, ,$(call get_src_lang,$1))),$(VSIM_VHDL_LRM))
get_run_name = $(foreach x,$1,$(word 1,$(subst =, ,$x)))
get_run_lib  = $(if $(findstring :,$(word 1,$(subst ;, ,$1))),$(word 1,$(subst :, ,$(word 2,$(subst =, ,$1)))),$(VSIM_WORK))
get_run_unit = $(if $(findstring :,$(word 1,$(subst ;, ,$1))),$(word 2,$(subst :, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$1)))))),$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$1)))))
get_run_gen  = $(subst $(comma), ,$(word 2,$(subst ;, ,$1)))

# compilation dependencies enforce compilation order
dep:=$(firstword $(VSIM_SRC))<= $(if $(word 2,$(VSIM_SRC)),$(call pairmap,src_dep,$(call rest,$(VSIM_SRC)),$(call chop,$(VSIM_SRC))),)

# extract libraries from sources
VSIM_LIB=$(call nodup,$(call get_src_lib,$(VSIM_SRC)))

################################################################################
# rules and recipes

# main directory
$(VSIM_DIR):
	$(MKDIR) -p $@

# modelsim.ini
$(VSIM_DIR)/$(VSIM_INI): | $(VSIM_DIR)
	cd $(VSIM_DIR) && $(VMAP) -c && [ -f $(VSIM_INI) ] || mv modelsim.ini $(VSIM_INI)

# libraries
define vsim_lib
$(VSIM_DIR)/$1: | $(VSIM_DIR)/$(VSIM_INI)
	cd $$(VSIM_DIR) && vlib $1
	cd $$(VSIM_DIR) && $(VMAP) -modelsimini $(VSIM_INI) $1 $1
endef
$(foreach l,$(VSIM_LIB),$(eval $(call vsim_lib,$l)))

# touch directories to track compilation
$(VSIM_DIR)/.touch:
	$(MKDIR) -p $@
define rr_touchdir
$(VSIM_DIR)/$1/.touch:
	$(MKDIR) -p $$@
endef
$(foreach l,$(VSIM_LIB),$(eval $(call rr_touchdir,$l)))

# compilation
# $1 = source path/file
# $2 = source library
# $3 = LRM
# $4 = dependency source path/file
# $5 = dependency source library
define rr_com
$(VSIM_DIR)/$(strip $2)/.touch/$(notdir $(strip $1)): $(strip $1) $(if $(strip $4),$(VSIM_DIR)/$(strip $5)/.touch/$(notdir $(strip $4))) $(if $(filter dev,$(MAKECMDGOALS)),,$($MAKEFILE_LIST)) | $(VSIM_DIR)/$(strip $2) $(VSIM_DIR)/$(strip $2)/.touch
	cd $(VSIM_DIR) && $(VCOM) \
		-modelsimini $(VSIM_INI) \
		-work $2 \
		-$(strip $3) \
		$(VCOM_OPTS) \
		$$<
	touch $$@
endef
$(foreach d,$(dep),$(eval $(call rr_com, \
	$(call get_src_file, $(word 1,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 1,$(subst <=, ,$d))), \
	$(call get_src_lrm,  $(word 1,$(subst <=, ,$d))), \
	$(call get_src_file, $(word 2,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 2,$(subst <=, ,$d)))  \
)))

# simulation run
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
.PHONY: vsim
define rr_run
.PHONY: vsim.$(strip $1)
vsim.$(strip $1):: $(VSIM_DIR)/$(call get_src_lib,$(lastword $(VSIM_SRC)))/.touch/$(notdir $(call get_src_file,$(lastword $(VSIM_SRC)))) | $(VSIM_DIR)/.touch
	cd $(VSIM_DIR) && $(VSIM) \
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
	$(call get_run_lib,  $r), \
	$(call get_run_unit, $r), \
	$(call get_run_gen,  $r)  \
)))

# compilation do file
# $1 = source path/file
# $2 = source library
# $3 = LRM
define rr_do_com
vcom -modelsimini $(VSIM_INI) -work $2 -$3 $(VCOM_OPTS) $1
endef

# simulation run do file
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
define rr_do_run
proc run_$1 {} { vsim -modelsimini $(VSIM_INI) -work $(VSIM_WORK) $(VSIM_OPTS) -do "$(VSIM_TCL_DO)" $3 $(addprefix -g,$4) }
endef

.PHONY: vsim_do
$(VSIM_DIR)/$(VCOM_DO): vsim_force | $(VSIM_DIR)
	@printf "# generated by vsim.mak" > $@
	@printf "$(foreach d,$(dep),\n$(call rr_do_com,$(call get_src_file,$(word 1,$(subst <=, ,$d))),$(call get_src_lib,$(word 1,$(subst <=, ,$d))),$(call get_src_lrm,$(word 1,$(subst <=, ,$d)))))\n" >> $@
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
#
################################################################################

clean::
	@rm -rf $(VSIM_DIR)