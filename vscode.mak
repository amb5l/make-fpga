################################################################################
# vscode.mak
# A part of make-fpga: see https://github.com/amb5l/make-fpga
################################################################################
# Visual Studio Code support
#
# Required definitions:
# Either
#	VSCODE_SRC    list of source files for work library
# Or
#	VSCODE_LIB    list of library names
#	VSCODE_SRC.x  list of source files for each library name "x"
# Optional definitions:
#	V4P_TOP       list of top entities
################################################################################

ifndef _VSCODE_MAK_

.PHONY: vscode

REPO_ROOT?=$(shell git rev-parse --show-toplevel)
ifeq ($(OS),Windows_NT)
REPO_ROOT?=$(shell cygpath -m $(REPO_ROOT))
endif
MAKE_FPGA?=$(REPO_ROOT)/submodules/make-fpga
include $(MAKE_FPGA)/utils.mak

# executable
VSCODE?=code

# workspace directory
VSCODE_DIR?=.vscode

# basic checks
ifdef VSCODE_SRC
ifndef VSCODE_LIB
VSCODE_LIB:=work
VSCODE_SRC.work=$(VSCODE_SRC)
else
$(error vscode.mak: VSCODE_LIB definition clashes with VSCODE_SRC)
endif
else
$(call check_null,VSCODE_LIB)
$(foreach l,$(VSCODE_LIB),$(call check_null,VSCODE_SRC.$l))
endif

# fresh start every time
vscode:: force
	bash -c "rm -rf $(VSCODE_DIR)"

# create directories
define RR_VSCODE_DIR
$1:
	bash -c "mkdir -p $1"
endef
$($eval $(call RR_VSCODE_DIR,$(VSCODE_DIR)))
$(foreach l,$(VSCODE_LIB),$(eval $(call RR_VSCODE_DIR,$(VSCODE_DIR)/$l)))

# create symlinks
define RR_VSCODE_SYMLINK
ifeq ($(OS),Windows_NT)
$(VSCODE_DIR)/$1/$(notdir $2): $2 | $(VSCODE_DIR)/$1
	rm -f $$@
	bash -c "cmd.exe //C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
else
$(VSCODE_DIR)/$1/$(notdir $2): $2 | $(VSCODE_DIR)/$1
	ln $$< $$@
endif
endef
$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),$(eval $(call RR_VSCODE_SYMLINK,$l,$s))))
VSCODE_SYMLINKS:=$(foreach l,$(VSCODE_LIB),$(addprefix $(VSCODE_DIR)/$l/,$(notdir $(VSCODE_SRC.$l))))

# V4P support
CONFIG_V4P_FILE:=$(VSCODE_DIR)/config.v4p
CONFIG_V4P_LINES:= \
	[libraries] \
	$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),$l/$(notdir $s)=$l)) \
	[settings] \
	$(addprefix V4p.Settings.Basics.TopLevelEntities=,$(subst $(SPACE),$(COMMA),$(V4P_TOP)))
$(CONFIG_V4P_FILE): force | $(VSCODE_DIR)
	@echo $(CONFIG_V4P_LINES) | tr " " "\n" > $(CONFIG_V4P_FILE)

# run editor
vscode:: $(VSCODE_SYMLINKS) $(CONFIG_V4P_FILE)
	$(VSCODE) $(VSCODE_DIR)

endif
