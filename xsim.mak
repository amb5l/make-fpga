	################################################################################
# xsim.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
# name
# XSIM_VHDL_LRM  VHDL LRM if not specified per source file (default: 2008)
# XSIM_SRC       sources to compile
#                  path/file<=lib><;language> <path/file<=lib><;language>> ...
# XSIM_RUN       list of simulation runs, each as follows:
#                  name=lib:unit<;generic=value<,generic=value...>>
#               For a single run, name= may be omitted and defaults to 'sim='
# XSIM_G_OPTS    global options
# XSIM_A_OPTS    analysis options
# XSIM_E_OPTS    elaboration options
# XSIM_R_OPTS    run options
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak


# defaults
.PHONY: xsim_default xsim_force
xsim_default: xsim
xsim_force:
XVHDL?=xvhdl
XELAB?=xelab
XSIM?=xsim
XSIM_DIR?=sim_xsim
XSIM_WORK?=work
XSIM_VHDL_LRM?=2008
XVHDL_OPTS?=-relax
XELAB_OPTS?=-debug typical -O2 -relax
XSIM_OPTS?=-onerror quit -onfinish quit

# checks
$(if $(strip $(XSIM_SRC)),,$(error XSIM_SRC not defined))
$(if $(strip $(XSIM_RUN)),,$(error XSIM_RUN not defined))
ifneq (1,$(words $(XSIM_RUN)))
$(foreach r,$(XSIM_RUN),$(if $(findstring =,$(word 1,$(subst ;, ,$r))),,$(error Multiple simulation runs must be named)))
else
$(if $(findstring =,$(word 1,$(subst ;, ,$(XSIM_RUN)))),,$(eval XSIM_RUN=sim=$(value XSIM_RUN)))
endif
$(if $(filter 1993 2000 2008,$(XSIM_VHDL_LRM)),,$(error XSIM_VHDL_LRM value is unsupported: $(XSIM_VHDL_LRM)))
$(foreach s,$(XSIM_SRC),$(if $(filter 1993 2000 2008,$(call get_src_lrm,$s,$(XSIM_VHDL_LRM))),,$(error source file LRM is unsupported: $s)))

# compilation dependencies enforce compilation order
dep:=$(firstword $(XSIM_SRC))<= $(if $(word 2,$(XSIM_SRC)),$(call pairmap,src_dep,$(call rest,$(XSIM_SRC)),$(call chop,$(XSIM_SRC))),)

# extract libraries from sources
XSIM_LIB=$(call nodup,$(call get_src_lib,$(XSIM_SRC),$(XSIM_WORK)))

################################################################################
# rules and recipes

# touch directories to track compilation
define rr_touchdir
$(XSIM_DIR)/$1/.touch:
	@$(MKDIR) -p $$@
endef
$(foreach l,$(XSIM_LIB),$(eval $(call rr_touchdir,$l)))

# compilation
# $1 = source path/file
# $2 = source library
# $3 = LRM
# $4 = dependency source path/file
# $5 = dependency source library
define rr_com
$(XSIM_DIR)/$(strip $2)/.touch/$(notdir $(strip $1)): $(strip $1) $(if $(strip $4),$(XSIM_DIR)/$(strip $5)/.touch/$(notdir $(strip $4))) | $(XSIM_DIR)/$(strip $2)/.touch
	@cd $(XSIM_DIR) && $(XVHDL) \
		$(if $(filter $3,2000),,$(if $(filter $3,1993),-93_mode,$(if $(filter $3,2008),-2008))) \
		$(XVHDL_OPTS) \
		-work $(strip $2) \
		$(strip $1)
	@touch $$@
endef
$(foreach d,$(dep),$(eval $(call rr_com, \
	$(call get_src_file, $(word 1,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 1,$(subst <=, ,$d)),$(XSIM_WORK)), \
	$(call get_src_lrm,  $(word 1,$(subst <=, ,$d)),$(XSIM_VHDL_LRM)), \
	$(call get_src_file, $(word 2,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 2,$(subst <=, ,$d)),$(XSIM_WORK))  \
)))

# simulation run batch tcl
$(XSIM_DIR)/run.tcl:
	printf "run all; quit" > $@

# simulation run
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
.PHONY: xsim
define rr_run
.PHONY: xsim.$(strip $1)
xsim.$(strip $1):: $(XSIM_DIR)/$(call get_src_lib,$(lastword $(XSIM_SRC)),$(XSIM_WORK))/.touch/$(notdir $(call get_src_file,$(lastword $(XSIM_SRC)))) | $(XSIM_DIR)/run.tcl
	$(call banner,XSIM: simulation run = $1)
	@cd $(XSIM_DIR) && $(XELAB) \
		$(XELAB_OPTS) \
		-L $(strip $2) \
		-top $(strip $3) \
		-snapshot $(strip $2).$(strip $3) \
		$(foreach g,$4,-generic_top "$g")
	@cd $(XSIM_DIR) && $(XSIM) \
		$(XSIM_OPTS) \
		-tclbatch run.tcl \
		$(strip $2).$(strip $3)
xsim:: xsim.$(strip $1)
endef
$(foreach r,$(XSIM_RUN),$(eval $(call rr_run, \
	$(call get_run_name, $r), \
	$(call get_run_lib,  $r), \
	$(call get_run_unit, $r), \
	$(call get_run_gen,  $r)  \
)))

################################################################################
# Visual Studio Code

XSIM_EDIT_DIR=edit/xsim
XSIM_EDIT_TOP=$(call nodup,$(call get_run_unit,$(XSIM_RUN)))
XSIM_EDIT_SRC=$(XSIM_SRC)
XSIM_EDIT_LIB=$(call nodup,$(call get_src_lib,$(XSIM_EDIT_SRC),$(XSIM_WORK)))
$(foreach l,$(XSIM_EDIT_LIB), \
	$(foreach s,$(XSIM_EDIT_SRC), \
		$(if $(filter $l,$(call get_src_lib,$s,$(XSIM_WORK))), \
			$(eval XSIM_EDIT_SRC.$l+=$(call get_src_file,$s)) \
		) \
	) \
)

# workspace directory
$(XSIM_EDIT_DIR):
	@$(MKDIR) -p $@

# library directory(s) containing symbolic link(s) to source(s)
$(foreach l,$(XSIM_EDIT_LIB),$(eval $l: $(addprefix $$(XSIM_EDIT_DIR)/$l/,$(notdir $(XSIM_EDIT_SRC.$l)))))

# symbolic links to source files
define rr_srclink
$$(XSIM_EDIT_DIR)/$1/$(notdir $2): $2
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach l,$(XSIM_EDIT_LIB),$(foreach s,$(XSIM_EDIT_SRC.$l),$(eval $(call rr_srclink,$l,$s))))

# symbolic links to auxilliary text files
define rr_auxlink
$$(XSIM_EDIT_DIR)/$(notdir $1): $1
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach a,$(XSIM_EDIT_AUX),$(eval $(call rr_auxlink,$a)))

# V4P configuration file
$(XSIM_EDIT_DIR)/config.v4p: xsim_force $(XSIM_EDIT_LIB)
	$(file >$@,[libraries])
	$(foreach l,$(XSIM_EDIT_LIB),$(foreach s,$(XSIM_EDIT_SRC.$l),$(file >>$@,$l/$(notdir $s)=$l)))
	$(file >>$@,[settings])
	$(file >>$@,V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(strip $(XSIM_EDIT_TOP))))

edit:: $(XSIM_EDIT_DIR)/config.v4p $(addprefix $(XSIM_EDIT_DIR)/,$(XSIM_EDIT_LIB)) $(addprefix $(XSIM_EDIT_DIR)/,$(notdir $(XSIM_EDIT_AUX)))
ifeq ($(OS),Windows_NT)
	@cd $(XSIM_EDIT_DIR) && start code .
else
	@cd $(XSIM_EDIT_DIR) && code . &
endif

################################################################################

clean::
	@rm -rf $(XSIM_DIR)
