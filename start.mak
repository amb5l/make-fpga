################################################################################
# start.mak
# A part of make-fpga: see https://github.com/amb5l/make-fpga
################################################################################

ifndef _START_MAK_

_START_MAK_:=defined

check_null_error=$(eval $(if $($1),,$(error $1 is empty)))
check_null_warning=$(eval $(if $($1),,$(info Warning: $1 is empty)))
check_path=$(if $(filter $1,$(notdir $(word 1,$(shell which $1 2>&1)))),,$(error $1: executable not found in path))
check_file=$(if $(filter $1,$(wildcard $1)),,$(error $1: file not found))
check_shell_error=$(if $(filter 0,$(.SHELLSTATUS)),,$(error $1))
mabspath=$(if $(filter Windows_NT,$(OS)),$(shell cygpath -m $(abspath $1)),$(abspath $1))
mpath=$(if $(filter Windows_NT,$(OS)),$(shell cygpath -m $1),$1)

DUMMY:=$(shell git -v)
$(call check_shell_error,Could not run git)
REPO_ROOT?=$(call mpath,$(shell git rev-parse --show-toplevel))
DUMMY:=$(shell pwd --version)
$(call check_shell_error,Could not run pwd)
MAKE_DIR:=$(call mpath,$(shell pwd))
ifeq ($(OS),Windows_NT)
DUMMY:=$(shell cygpath -V)
$(call check_shell_error,Could not run cygpath)
$(call check_null_error,MSYS2)
MSYS2:=$(call mpath,$(MSYS2))
export PATH:=$(MSYS2)/usr/bin:$(PATH)
endif
MAKE_FPGA?=$(REPO_ROOT)/submodules/make-fpga

endif
