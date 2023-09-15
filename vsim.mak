################################################################################
# radiant.mak
# ModelSim/Questa simulator support for make-fpga
# See https://github.com/amb5l/make-fpga
################################################################################
# Targets:
#   vsim_do              DO file e.g. for use with IDE
#	vsim                 compile and simulate run(s)
#
# Required definitions:
# either
#	VSIM_SRC             Sources for work library
# or
#	VSIM_SRC.lib         Source(s) for <lib> where <lib> = library name(s)
#
# Optional definitions:
#	VSIM_LIB             Library name(s) (defaults to work)
################################################################################

ifndef _START_MAK_
$(error start.mak is required before vsim.mak)
endif

.PHONY: vsim
vsim::
	$(call banner,BLU,WHT,make-fpga: vsim recipe)

VSIM_WORK?=work
VSIM_DIR?=.vsim
VSIM_TOUCH_DIR:=$(VSIM_DIR)/.touch
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
VLIB:=$(shell cygpath -m $(VLIB))
VMAP:=$(shell cygpath -m $(VMAP))
VCOM:=$(shell cygpath -m $(VCOM))
VSIM:=$(shell cygpath -m $(VSIM))
endif

VCOM_OPTS+=-2008 -explicit -stats=none
VSIM_TCL+=set NumericStdNoWarnings 1; onfinish exit; run -all; exit
VSIM_OPTS+=-t ps -c -onfinish stop -do "$(VSIM_TCL)"

vsim_do:: $(VSIM_DIR)/$(VSIM_DO)

define vsim_lib
$(VSIM_DIR)/$1: | $(VSIM_DIR)/$(VSIM_INI)
	cd $$(VSIM_DIR) && $(VLIB) $1
	cd $$(VSIM_DIR) && $(VMAP) -modelsimini $(VSIM_INI) $1 $1
endef

# $1 = output touch file
# $2 = library
# $3 = source file
# $4 = dependencies (touch files)
define vsim_com
$1: $3 $4 | $(dir $1). $(VSIM_DIR)/$2 $(VSIM_DIR)/$(VSIM_INI) $(VSIM_DIR)/$(VSIM_DO)
	cd $$(VSIM_DIR) && $$(VCOM) -modelsimini $(VSIM_INI) -work $2 $$(VCOM_OPTS) $$<
	@touch $$@ $$(dir $$@).
vsim:: $1
vsim_do:: $3
	$$(file >>$(VSIM_DIR)/$(VSIM_DO),vcom -modelsimini $(VSIM_INI) -work $2 $$(VCOM_OPTS) $$<)
endef

define vsim_run
vsim:: force | $(VSIM_DIR)/$(VSIM_INI)
	$$(call banner,WHT,BLU,simulation run: $$(word 1,$1)  top: $$(word 2,$1)  start at: ($$$$(date +"%T.%2N")))
	cd $$(VSIM_DIR) && $$(VSIM) \
		-modelsimini $(VSIM_INI) \
		-work $$(VSIM_WORK) \
		$$(VSIM_OPTS) \
		$$(word 2,$1) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1)))
	$$(call banner,WHT,BLU,simulation run: $$(word 1,$1)  finish at: ($$$$(date +"%T.%2N")))
vsim_do:: force | $(VSIM_DIR)/$(VSIM_INI)
	$$(file >>$(VSIM_DIR)/$(VSIM_DO),vsim \
		-modelsimini $(VSIM_INI) \
		-work $$(VSIM_WORK) \
		$$(VSIM_OPTS) \
		$$(word 2,$1) \
		$$(addprefix -g,$$(subst $(SEMICOLON),$(SPACE),$$(word 3,$1))) \
	)
endef

$(VSIM_DIR):
	@bash -c "mkdir -p $(VSIM_DIR)"

$(VSIM_DIR)/$(VSIM_INI): | $(VSIM_DIR)
	bash -c "cd $(VSIM_DIR) && $(VMAP) -c && [ -f $(VSIM_INI) ] || mv modelsim.ini $(VSIM_INI)"

$(VSIM_DIR)/$(VSIM_DO): | $(VSIM_DIR)
	$(file >$(VSIM_DIR)/$(VSIM_DO),# make-fpga)

$(foreach l,$(VSIM_LIB),$(eval $(call vsim_lib,$l)))
$(eval $(call sim_com_all,$(VSIM_TOUCH_DIR),vsim,VSIM_SRC,$(VSIM_LIB)))
$(foreach r,$(call SIM_RUNX,$(VSIM_RUN)),$(eval $(call vsim_run,$(subst $(COMMA),$(SPACE),$r))))
