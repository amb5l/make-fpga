################################################################################
# ghdl.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
# name
# GHDL_LRM         VHDL LRM if not specified per source file (default: 2008)
# GHDL_SRC         sources to compile
#                    path/file<=lib><;language> <path/file<=lib><;language>> ...
# GHDL_VENDOR_LIB  list of vendor libraries e.g. xilinx-vivado
# GHDL_RUN         list of simulation runs, each as follows:
#                    name=lib:unit<;generic=value<,generic=value...>>
#                  For a single run, name= may be omitted and defaults to 'sim='
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

# defaults
.PHONY: ghdl_default ghdl_force
ghdl_default: ghdl
ghdl_force:
GHDL?=ghdl
GHDL_DIR?=sim_ghdl
GHDL_WORK?=work
GHDL_LRM?=08
GHDL_VENDOR_LIB_PATH?=$(subst /,$(if $(filter Windows_NT,$(OS)),\,/),$(dir $(shell which $(GHDL)))../lib/ghdl/vendors/)
GHDL_AOPTS?=-fsynopsys -frelaxed -Wno-hide -Wno-shared $(addprefix -P$(GHDL_VENDOR_LIB_PATH),$(GHDL_VENDOR_LIB))
GHDL_EOPTS?=-fsynopsys -frelaxed $(addprefix -P$(GHDL_VENDOR_LIB_PATH),$(GHDL_VENDOR_LIB))
GHDL_ROPTS?=--max-stack-alloc=0 --ieee-asserts=disable

# checks
$(if $(strip $(GHDL_SRC)),,$(error GHDL_SRC not defined))
$(if $(strip $(GHDL_RUN)),,$(error GHDL_RUN not defined))
ifneq (1,$(words $(GHDL_RUN)))
$(foreach r,$(GHDL_RUN),$(if $(findstring =,$(word 1,$(subst ;, ,$r))),,$(error Multiple simulation runs must be named)))
else
$(if $(findstring =,$(word 1,$(subst ;, ,$(GHDL_RUN)))),,$(eval GHDL_RUN=sim=$(value GHDL_RUN)))
endif
$(if $(filter 1987 1993 2002 2008 2019,$(GHDL_LRM)),,$(error GHDL_LRM value is unsupported: $(GHDL_LRM)))
$(foreach s,$(GHDL_SRC),$(if $(filter 1987 1993 2002 2008 2019,$(call get_src_lrm,$s,$(GHDL_LRM))),,$(error source file LRM is unsupported: $s)))

# compilation dependencies enforce compilation order
dep:=$(firstword $(GHDL_SRC))<= $(if $(word 2,$(GHDL_SRC)),$(call pairmap,src_dep,$(call rest,$(GHDL_SRC)),$(call chop,$(GHDL_SRC))),)

# extract libraries from sources
GHDL_LIB=$(call nodup,$(call get_src_lib,$(GHDL_SRC),$(GHDL_WORK)))

################################################################################
# rules and recipes

# touch directories to track compilation
define rr_touchdir
$(GHDL_DIR)/$1/.touch:
	@$(MKDIR) -p $$@
endef
$(foreach l,$(GHDL_LIB),$(eval $(call rr_touchdir,$l)))

# compilation
# $1 = source path/file
# $2 = source library
# $3 = LRM
# $4 = dependency source path/file
# $5 = dependency source library
define rr_com
$(GHDL_DIR)/$(strip $2)/.touch/$(notdir $(strip $1)): $(strip $1) $(if $(strip $4),$(GHDL_DIR)/$(strip $5)/.touch/$(notdir $(strip $4))) | $(GHDL_DIR)/$(strip $2)/.touch
	@cd $(GHDL_DIR) && $(GHDL) -a --work=$(strip $2) --std=$(strip $3) $$(GHDL_AOPTS) $$<
	@touch $$@
endef
$(foreach d,$(dep),$(eval $(call rr_com, \
	$(call get_src_file, $(word 1,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 1,$(subst <=, ,$d)),$(GHDL_WORK)), \
	$(call get_src_lrm2, $(word 1,$(subst <=, ,$d)),$(GHDL_LRM)), \
	$(call get_src_file, $(word 2,$(subst <=, ,$d))), \
	$(call get_src_lib,  $(word 2,$(subst <=, ,$d)),$(GHDL_WORK))  \
)))

# simulation run
# $1 = run name
# $2 = design unit library
# $3 = design unit
# $4 = list of generic=value
.PHONY: ghdl
define rr_run
.PHONY: ghdl.$(strip $1)
ghdl.$(strip $1):: $(GHDL_DIR)/$(call get_src_lib,$(lastword $(GHDL_SRC)),$(GHDL_WORK))/.touch/$(notdir $(call get_src_file,$(lastword $(GHDL_SRC))))
	$(call banner,GHDL: simulation run = $1)
	@cd $(GHDL_DIR) && $(GHDL) \
		--elab-run \
		--work=$(strip $2) \
		--std=08 \
		$(GHDL_EOPTS) \
		$(strip $3) \
		$(GHDL_ROPTS) \
		$(addprefix -g,$(strip $4))
ghdl:: ghdl.$(strip $1)
endef
$(foreach r,$(GHDL_RUN),$(eval $(call rr_run, \
	$(call get_run_name, $r), \
	$(call get_run_lib,  $r), \
	$(call get_run_unit, $r), \
	$(call get_run_gen,  $r)  \
)))

################################################################################
# Visual Studio Code

GHDL_EDIT_DIR=edit/ghdl
GHDL_EDIT_TOP=$(call nodup,$(call get_run_unit,$(GHDL_RUN)))
GHDL_EDIT_SRC=$(GHDL_SRC)
GHDL_EDIT_LIB=$(call nodup,$(call get_src_lib,$(GHDL_EDIT_SRC),$(GHDL_WORK)))
$(foreach l,$(GHDL_EDIT_LIB), \
	$(foreach s,$(GHDL_EDIT_SRC), \
		$(if $(filter $l,$(call get_src_lib,$s,$(GHDL_WORK))), \
			$(eval GHDL_EDIT_SRC.$l+=$(call get_src_file,$s)) \
		) \
	) \
)

# workspace directory
$(GHDL_EDIT_DIR):
	@$(MKDIR) -p $@

# library directory(s) containing symbolic link(s) to source(s)
$(foreach l,$(GHDL_EDIT_LIB),$(eval $l: $(addprefix $$(GHDL_EDIT_DIR)/$l/,$(notdir $(GHDL_EDIT_SRC.$l)))))

# symbolic links to source files
define rr_srclink
$$(GHDL_EDIT_DIR)/$1/$(notdir $2): $2
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach l,$(GHDL_EDIT_LIB),$(foreach s,$(GHDL_EDIT_SRC.$l),$(eval $(call rr_srclink,$l,$s))))

# symbolic links to auxilliary text files
define rr_auxlink
$$(GHDL_EDIT_DIR)/$(notdir $1): $1
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach a,$(GHDL_EDIT_AUX),$(eval $(call rr_auxlink,$a)))

# V4P configuration file
$(GHDL_EDIT_DIR)/config.v4p: ghdl_force $(GHDL_EDIT_LIB)
	$(file >$@,[libraries])
	$(foreach l,$(GHDL_EDIT_LIB),$(foreach s,$(GHDL_EDIT_SRC.$l),$(file >>$@,$l/$(notdir $s)=$l)))
	$(file >>$@,[settings])
	$(file >>$@,V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(strip $(GHDL_EDIT_TOP))))

edit:: $(GHDL_EDIT_DIR)/config.v4p $(addprefix $(GHDL_EDIT_DIR)/,$(GHDL_EDIT_LIB)) $(addprefix $(GHDL_EDIT_DIR)/,$(notdir $(GHDL_EDIT_AUX)))
ifeq ($(OS),Windows_NT)
	@cd $(GHDL_EDIT_DIR) && start code .
else
	@cd $(GHDL_EDIT_DIR) && code . &
endif

################################################################################

clean::
	@rm -rf $(GHDL_DIR)
