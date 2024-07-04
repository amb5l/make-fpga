################################################################################
# nvc.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
# name
# NVC_LRM       VHDL LRM if not specified per source file (default: 2008)
# NVC_SRC       sources to compile
#				   path/file<=lib><;language> <path/file<=lib><;language>> ...
# NVC_RUN       list of simulation runs, each as follows:
#                 name=lib:unit<;generic=value<,generic=value...>>
#                 For a single run, name= may be omitted and defaults to 'sim='
# NVC_G_OPTS
# NVC_A_OPTS
# NVC_E_OPTS
# NVC_R_OPTS
################################################################################

# defaults
.PHONY: nvc_default
nvc_default: nvc
NVC?=nvc
NVC_DIR?=sim_nvc
NVC_WORK?=work
NVC_LRM?=2008
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

# definitions and functions
comma:=,
rest         = $(wordlist 2,$(words $1),$1)
chop         = $(wordlist 1,$(words $(call rest,$1)),$1)
src_dep      = $1<=$2
pairmap      = $(and $(strip $2),$(strip $3),$(call $1,$(firstword $2),$(firstword $3)) $(call pairmap,$1,$(call rest,$2),$(call rest,$3)))
nodup        = $(if $1,$(firstword $1) $(call nodup,$(filter-out $(firstword $1),$1)))
get_src_file = $(foreach x,$1,$(word 1,$(subst =, ,$(word 1,$(subst ;, ,$x)))))
get_src_lib  = $(foreach x,$1,$(if $(word 1,$(subst ;, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$x)))))),$(word 1,$(subst ;, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$x)))))),$(NVC_WORK)))
get_src_lang = $(word 1,$(subst =, ,$(word 2,$(subst ;, ,$1))))
get_src_lrm  = $(if $(findstring VHDL-,$(call get_src_lang,$1)),$(word 2,$(subst -, ,$(call get_src_lang,$1))),$(NVC_LRM))
get_run_name = $(foreach x,$1,$(word 1,$(subst =, ,$x)))
get_run_lib  = $(if $(findstring :,$(word 1,$(subst ;, ,$1))),$(word 1,$(subst :, ,$(word 2,$(subst =, ,$1)))),$(NVC_WORK))
get_run_unit = $(if $(findstring :,$(word 1,$(subst ;, ,$1))),$(word 2,$(subst :, ,$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$1)))))),$(word 2,$(subst =, ,$(word 1,$(subst ;, ,$1)))))
get_run_gen  = $(subst $(comma), ,$(word 2,$(subst ;, ,$1)))

# compilation dependencies enforce compilation order
dep:=$(firstword $(NVC_SRC))<= $(if $(word 2,$(NVC_SRC)),$(call pairmap,src_dep,$(call rest,$(NVC_SRC)),$(call chop,$(NVC_SRC))),)

# extract libraries from sources
NVC_LIB=$(call nodup,$(call get_src_lib,$(NVC_SRC)))

# main directory
$(NVC_DIR):
	bash -c "mkdir -p $@"

# touch directories to track analysis/compilation
define rr_touchdir
$(NVC_DIR)/$1/.touch:
	@bash -c "mkdir -p $$@"
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
	$(call get_src_lib,  $(word 1,$(subst <=, ,$d))), \
	$(call get_src_lrm,  $(word 1,$(subst <=, ,$d))), \
	$(call get_src_file, $(word 2,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 2,$(subst <=, ,$d)))  \
)))

# simulation runs (elaborate and run)
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
.PHONY: nvc
define rr_elabrun
.PHONY: nvc.$(strip $1)
nvc.$(strip $1):: $(NVC_DIR)/$(call get_src_lib,$(lastword $(NVC_SRC)))/.touch/$(notdir $(call get_src_file,$(lastword $(NVC_SRC))))
	cd $(NVC_DIR) && $(NVC) \
		$(NVC_G_OPTS) \
		--work=$(strip $2):$(strip $2) \
		-e \
		$(NVC_E_OPTS)\
		$(addprefix -g,$(strip $4)) \
		$(strip $3)
nvc:: nvc.$(strip $1)
endef
$(foreach r,$(NVC_RUN),$(eval $(call rr_elabrun, \
	$(call get_run_name, $r), \
	$(call get_run_lib,  $r), \
	$(call get_run_unit, $r), \
	$(call get_run_gen,  $r), \
)))
