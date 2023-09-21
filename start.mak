################################################################################
# start.mak
# A part of make-fpga: see https://github.com/amb5l/make-fpga
################################################################################
# TODO: banner function

ifndef _START_MAK_

_START_MAK_:=defined

################################################################################
# check OS

$(call check_null_error,MSYS2)
DUMMY:=$(shell cygpath -w ~)
$(call check_shell_error,Could not run cygpath)
MSYS2:=$(shell cygpath -m $(MSYS2))
export PATH:=$(MSYS2)/usr/bin:$(PATH)

################################################################################
# useful definitions

REPO_ROOT?=$(shell git rev-parse --show-toplevel)
MAKE_DIR:=$(shell pwd)
ifeq ($(OS),Windows_NT)
REPO_ROOT:=$(shell cygpath -m $(REPO_ROOT))
MAKE_DIR:=$(shell cygpath -m $(MAKE_DIR))
endif
MAKE_FPGA?=$(REPO_ROOT)/submodules/make-fpga
MAKE_FPGA_PY?=$(REPO_ROOT)/submodules/make-fpga/make_fpga.py

NULL:=
COMMA:=,
SEMICOLON:=;
SPACE:=$(subst x, ,x)
COL_RST:=\033[0m
COL_BG_BLK:=\033[0;40m
COL_BG_RED:=\033[0;41m
COL_BG_GRN:=\033[0;42m
COL_BG_YEL:=\033[0;43m
COL_BG_BLU:=\033[0;44m
COL_BG_MAG:=\033[0;45m
COL_BG_CYN:=\033[0;46m
COL_BG_WHT:=\033[0;47m
COL_FG_BLK:=\033[0;30m
COL_FG_RED:=\033[0;31m
COL_FG_GRN:=\033[0;32m
COL_FG_YEL:=\033[0;33m
COL_FG_BLU:=\033[0;34m
COL_FG_MAG:=\033[0;35m
COL_FG_CYN:=\033[0;36m
COL_FG_WHT:=\033[0;37m
CPU_CORES:=$(shell bash -c "grep '^core id' /proc/cpuinfo |sort -u|wc -l")

################################################################################
# useful functions

include $(MAKE_FPGA)/submodules/gmsl/gmsl

ifeq ($(OS),Windows_NT)
define mpath
$(shell cygpath -m $1)
endef
else
define mpath
$1
endef
endif

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

# run expansion
# single run: $1=top[,generics]
# multiple runs: $1=name1,top1[,generics1] name2,top2[,generics2] ...
define SIM_RUNX
$(if $(word 2,$1),$1,sim,$1)
endef

# recursively compile lib sources:
# $1 = touch dir e.g. .ghdl/.touch
# $2 = simulator e.g. ghdl
# $3 = root name of source list e.g. GHDL_SRC
# $4 = list of libs, last is working, others are deps
# $5 = list of sources, last is to be compiled, others are deps
define sim_com_lib
$(if $(word 2,$5),$(eval $(call sim_com_lib,$1,$2,$3,$4,$(call chop,$5))))
$(eval $(call $2_com,$1/$(call last,$4)/$(notdir $(call last,$5)).com,$(call last,$4),$(call last,$5),$(addprefix $1/$(call last,$4)/,$(addsuffix .com,$(notdir $(call chop,$5)))) $(foreach l,$(call chop,$4),$1/$l)))
endef

# recursively compile all libs:
# $1 = touch dir e.g. .ghdl/.touch
# $2 = simulator e.g. ghdl
# $3 = root name of source list e.g. GHDL_SRC
# $4 = list of libraries
define sim_com_all
$(if $(word 2,$4),$(eval $(call sim_com_all,$1,$2,$3,$(call chop,$4))))
$1/$(call last,$4)/.:
	bash -c "mkdir -p $$@"
$(eval $(call sim_com_lib,$1,$2,$3,$4,$($3.$(call last,$4))))
endef

hr80:=--------------------------------------------------------------------------------
define banner
@bash -c 'printf "$(COL_BG_$2)$(COL_FG_$1)$(hr80)$(COL_RST)\n"; printf "$(COL_BG_$2)$(COL_FG_$1) %-79s$(COL_RST)\n" "$3"; printf "$(COL_BG_$2)$(COL_FG_$1)$(hr80)$(COL_RST)\n"'
endef

################################################################################

.PHONY: all force
force:

################################################################################

endif
