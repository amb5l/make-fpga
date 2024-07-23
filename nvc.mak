################################################################################
# nvc.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
# name
# NVC_VHDL_LRM  VHDL LRM if not specified per source file (default: 2008)
# NVC_SRC       sources to compile
#                 path/file<=lib><;language> <path/file<=lib><;language>> ...
# NVC_RUN       list of simulation runs, each as follows:
#                 name=lib:unit<;generic=value<,generic=value...>>
#               For a single run, name= may be omitted and defaults to 'sim='
# NVC_G_OPTS    global options
# NVC_A_OPTS    analysis options
# NVC_E_OPTS    elaboration options
# NVC_R_OPTS    run options
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

# defaults
.PHONY: nvc_default
nvc_default: nvc
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

# compilation dependencies enforce compilation order
dep:=$(firstword $(NVC_SRC))<= $(if $(word 2,$(NVC_SRC)),$(call pairmap,src_dep,$(call rest,$(NVC_SRC)),$(call chop,$(NVC_SRC))),)

# extract libraries from sources
NVC_LIB=$(call nodup,$(call get_src_lib,$(NVC_SRC),$(NVC_WORK)))

################################################################################
# rules and recipes

# main directory
$(NVC_DIR):
	$(MKDIR) -p $@

# touch directories to track analysis/compilation and elaboration
$(NVC_DIR)/.touch:
	$(MKDIR) -p $@
define rr_touchdir
$(NVC_DIR)/$1/.touch:
	$(MKDIR) -p $$@
endef
$(foreach l,$(NVC_LIB),$(eval $(call rr_touchdir,$l)))

# analysis (compilation)
# $1 = source path/file
# $2 = source library
# $3 = LRM
# $4 = dependency source path/file
# $5 = dependency source library
define rr_analyse
$(NVC_DIR)/$(strip $2)/.touch/$(notdir $(strip $1)): $(strip $1) $(if $(strip $4),$(NVC_DIR)/$(strip $5)/.touch/$(notdir $(strip $4))) | $(NVC_DIR)/$(strip $2)/.touch
	cd $(NVC_DIR) && $(NVC) \
		$(NVC_G_OPTS) \
		--std=$(strip $3) \
		--work=$(strip $2):$(strip $2) \
		-a \
		$(NVC_A_OPTS)\
		$(strip $1)
	touch $$@
endef
$(foreach d,$(dep),$(eval $(call rr_analyse, \
	$(call get_src_file, $(word 1,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 1,$(subst <=, ,$d)),$(NVC_WORK)), \
	$(call get_src_lrm,  $(word 1,$(subst <=, ,$d)),$(NVC_VHDL_LRM)), \
	$(call get_src_file, $(word 2,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 2,$(subst <=, ,$d)),$(NVC_WORK))  \
)))

# elaboration
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
define rr_elaborate
$(NVC_DIR)/.touch/$(strip $1): $(NVC_DIR)/$(call get_src_lib,$(lastword $(NVC_SRC)),$(NVC_WORK))/.touch/$(notdir $(call get_src_file,$(lastword $(NVC_SRC)))) | $(NVC_DIR)/.touch
	cd $(NVC_DIR) && $(NVC) \
		$(NVC_G_OPTS) \
		--work=$(strip $2):$(strip $2) \
		-e \
		$(NVC_E_OPTS)\
		$(addprefix -g,$(strip $4)) \
		$(strip $3)
	touch $$@
endef
$(foreach r,$(NVC_RUN),$(eval $(call rr_elaborate, \
	$(call get_run_name, $r), \
	$(call get_run_lib,  $r), \
	$(call get_run_unit, $r), \
	$(call get_run_gen,  $r)  \
)))

# simulation run
# $1 = run name
# $2 = design unit library
# $3 = design unit
.PHONY: nvc
define rr_run
.PHONY: nvc.$(strip $1)
nvc.$(strip $1):: $(NVC_DIR)/.touch/$(strip $1)
	cd $(NVC_DIR) && $(NVC) \
		$(NVC_G_OPTS) \
		--work=$(strip $2):$(strip $2) \
		-r \
		$(NVC_R_OPTS)\
		$(strip $3)
nvc:: nvc.$(strip $1)
endef
$(foreach r,$(NVC_RUN),$(eval $(call rr_run, \
	$(call get_run_name, $r), \
	$(call get_run_lib,  $r), \
	$(call get_run_unit, $r), \
)))

################################################################################

clean::
	@rm -rf $(NVC_DIR)
