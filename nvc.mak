################################################################################
# nvc.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
# NVC_VHDL_LRM  VHDL LRM if not specified per source file (default: 2008)
# NVC_SRC       sources to compile
#                 path/file<=lib><;language> <path/file<=lib><;language>> ...
# NVC_RUN       list of simulation runs, each as follows:
#                 name=<lib:>:unit<;generic=value<,generic=value...>>
#               For a single run, name= may be omitted and defaults to 'sim='
# NVC_G_OPTS    global options
# NVC_A_OPTS    analysis options
# NVC_E_OPTS    elaboration options
# NVC_R_OPTS    run options
# NVC_EDIT      Set to 0 to disable Visual Studio Code 'edit' goal.
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

# defaults
.PHONY: nvc_default nvc_force
nvc_default: nvc
nvc_force:
NVC?=nvc
NVC_DIR?=sim_nvc
NVC_WORK?=work
NVC_VHDL_LRM?=2008
NVC_G_OPTS?=-H 128M
NVC_A_OPTS?=--relaxed
NVC_E_OPTS?=
NVC_R_OPTS?=--ieee-warnings=off

# checks
$(if $(strip $(NVC_SRC)),,$(error NVC_SRC not defined))
$(if $(strip $(NVC_RUN)),,$(error NVC_RUN not defined))
ifneq (1,$(words $(NVC_RUN)))
$(foreach r,$(NVC_RUN),$(if $(findstring =,$(word 1,$(subst ;, ,$r))),,$(error Multiple simulation runs must be named)))
else
$(if $(findstring =,$(word 1,$(subst ;, ,$(NVC_RUN)))),,$(eval NVC_RUN=sim=$(value NVC_RUN)))
endif
$(if $(filter 1993 2000 2002 2008 2019,$(NVC_VHDL_LRM)),,$(error NVC_VHDL_LRM value is unsupported: $(NVC_VHDL_LRM)))
$(foreach s,$(NVC_SRC),$(if $(filter 1993 2000 2002 2008 2019,$(call get_src_lrm,$s,$(NVC_VHDL_LRM))),,$(error source file LRM is unsupported: $s)))

# compilation dependencies enforce compilation order
dep:=$(firstword $(NVC_SRC))<= $(if $(word 2,$(NVC_SRC)),$(call pairmap,src_dep,$(call rest,$(NVC_SRC)),$(call chop,$(NVC_SRC))),)

# extract libraries from sources
NVC_LIB=$(call nodup,$(call get_src_lib,$(NVC_SRC),$(NVC_WORK)))

################################################################################
# rules and recipes

# touch directories to track compilation
define rr_touchdir
$(NVC_DIR)/$1/.touch:
	@$(MKDIR) -p $$@
endef
$(foreach l,$(NVC_LIB),$(eval $(call rr_touchdir,$l)))

# compilation
# $1 = source path/file
# $2 = source library
# $3 = LRM
# $4 = dependency source path/file
# $5 = dependency source library
define rr_com
$(NVC_DIR)/$(strip $2)/.touch/$(notdir $(strip $1)): $(strip $1) $(if $(strip $4),$(NVC_DIR)/$(strip $5)/.touch/$(notdir $(strip $4))) | $(NVC_DIR)/$(strip $2)/.touch
	@cd $(NVC_DIR) && $(NVC) \
		$(NVC_G_OPTS) \
		--std=$(strip $3) \
		--work=$(strip $2):$(strip $2) \
		-a \
		$(NVC_A_OPTS)\
		$(strip $1)
	@touch $$@
endef
$(foreach d,$(dep),$(eval $(call rr_com, \
	$(call get_src_file, $(word 1,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 1,$(subst <=, ,$d)),$(NVC_WORK)), \
	$(call get_src_lrm,  $(word 1,$(subst <=, ,$d)),$(NVC_VHDL_LRM)), \
	$(call get_src_file, $(word 2,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 2,$(subst <=, ,$d)),$(NVC_WORK))  \
)))

# simulation run
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
.PHONY: nvc
define rr_run
.PHONY: nvc.$(strip $1)
nvc.$(strip $1):: $(NVC_DIR)/$(call get_src_lib,$(lastword $(NVC_SRC)),$(NVC_WORK))/.touch/$(notdir $(call get_src_file,$(lastword $(NVC_SRC))))
	$(call banner,NVC: simulation run = $(strip $1))
	@cd $(NVC_DIR) && $(NVC) \
		$(NVC_G_OPTS) \
		--work=$(strip $2):$(strip $2) \
		-e \
		$(NVC_E_OPTS)\
		$(addprefix -g,$(strip $4)) \
		$(strip $3) \
		-r \
		$(NVC_R_OPTS)\
		$(strip $3)
nvc:: nvc.$(strip $1)
endef
$(foreach r,$(NVC_RUN),$(eval $(call rr_run, \
	$(call get_run_name, $r), \
	$(call get_run_lib,  $r, $(NVC_WORK)), \
	$(call get_run_unit, $r), \
	$(call get_run_gen,  $r)  \
)))

################################################################################
# Visual Studio Code

ifneq (0,$(NVC_EDIT))

NVC_EDIT_DIR=edit/nvc
NVC_EDIT_TOP=$(call nodup,$(call get_run_unit,$(NVC_RUN)))
NVC_EDIT_SRC=$(NVC_SRC)
NVC_EDIT_LIB=$(call nodup,$(call get_src_lib,$(NVC_EDIT_SRC),$(NVC_WORK)))
$(foreach l,$(NVC_EDIT_LIB), \
	$(foreach s,$(NVC_EDIT_SRC), \
		$(if $(filter $l,$(call get_src_lib,$s,$(NVC_WORK))), \
			$(eval NVC_EDIT_SRC.$l+=$(call get_src_file,$s)) \
		) \
	) \
)

# workspace directory
$(NVC_EDIT_DIR):
	@$(MKDIR) -p $@

# library directory(s) containing symbolic link(s) to source(s)
$(foreach l,$(NVC_EDIT_LIB),$(eval $l: $(addprefix $$(NVC_EDIT_DIR)/$l/,$(notdir $(NVC_EDIT_SRC.$l)))))

# symbolic links to source files
define rr_srclink
$$(NVC_EDIT_DIR)/$1/$(notdir $2): $2
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach l,$(NVC_EDIT_LIB),$(foreach s,$(NVC_EDIT_SRC.$l),$(eval $(call rr_srclink,$l,$s))))

# symbolic links to auxilliary text files
define rr_auxlink
$$(NVC_EDIT_DIR)/$(notdir $1): $1
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach a,$(NVC_EDIT_AUX),$(eval $(call rr_auxlink,$a)))

# V4P configuration file
$(NVC_EDIT_DIR)/config.v4p: nvc_force $(NVC_EDIT_LIB)
	$(file >$@,[libraries])
	$(foreach l,$(NVC_EDIT_LIB),$(foreach s,$(NVC_EDIT_SRC.$l),$(file >>$@,$l/$(notdir $s)=$l)))
	$(file >>$@,[settings])
	$(file >>$@,V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(strip $(NVC_EDIT_TOP))))

edit:: $(NVC_EDIT_DIR)/config.v4p $(addprefix $(NVC_EDIT_DIR)/,$(NVC_EDIT_LIB)) $(addprefix $(NVC_EDIT_DIR)/,$(notdir $(NVC_EDIT_AUX)))
ifeq ($(OS),Windows_NT)
	@cd $(NVC_EDIT_DIR) && start code .
else
	@cd $(NVC_EDIT_DIR) && code . &
endif

endif

################################################################################

help::
	$(call print_col,col_fi_cyn,  nvc.mak)
	$(call print_col,col_fi_wht,  Support for simulation with NVC.)
	$(call print_col,col_fg_wht, )
	$(call print_col,col_fg_wht,    Goals:)
	$(call print_col,col_fi_grn,      nvc       $(col_fg_wht)- perform all simulation runs)
	$(call print_col,col_fi_grn,      nvc.<run> $(col_fg_wht)- perform specified simulation run)
	$(call print_col,col_fi_grn,      edit      $(col_fg_wht)- create and open Visual Studio Code workspace directory)
	$(call print_col,col_fg_wht, )

################################################################################

clean::
	@rm -rf $(NVC_DIR)
