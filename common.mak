################################################################################
# common.mak
# A part of make-fpga: see https://github.com/amb5l/make-fpga
################################################################################

ifndef _COMMON_MAK_

_COMMON_MAK_:=defined

REPO_ROOT?=$(shell git rev-parse --show-toplevel)
ifeq ($(OS),Windows_NT)
REPO_ROOT?=$(shell cygpath -m $(REPO_ROOT))
endif
MAKE_FPGA?=$(REPO_ROOT)/submodules/make-fpga

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
define check_shell_error
$(if $(filter 0,$(.SHELLSTATUS)),,$(error $1))
endef

# check OS
$(call check_null_error,MSYS2)
DUMMY:=$(shell cygpath -w ~)
$(call check_shell_error,Could not run cygpath)
MSYS2:=$(shell cygpath -m $(MSYS2))
export PATH:=$(MSYS2)/usr/bin:$(PATH)

# useful definitions
NULL:=
COMMA:=,
SEMICOLON:=;
SPACE:=$(subst x, ,x)
COL_RST:=\033[0m
COL_BG_BLK:=\033[0;100m
COL_BG_RED:=\033[0;101m
COL_BG_GRN:=\033[0;102m
COL_BG_YEL:=\033[0;103m
COL_BG_BLU:=\033[0;104m
COL_BG_MAG:=\033[0;105m
COL_BG_CYN:=\033[0;106m
COL_BG_WHT:=\033[0;107m
COL_FG_BLK:=\033[1;30m
COL_FG_RED:=\033[1;31m
COL_FG_GRN:=\033[1;32m
COL_FG_YEL:=\033[1;33m
COL_FG_BLU:=\033[1;34m
COL_FG_MAG:=\033[1;35m
COL_FG_CYN:=\033[1;36m
COL_FG_WHT:=\033[1;37m
CPU_CORES:=$(shell bash -c "grep '^core id' /proc/cpuinfo |sort -u|wc -l")

.PHONY: all force
force:

endif
