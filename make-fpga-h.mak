REPO_ROOT:=$(shell git rev-parse --show-toplevel)
MAKE_DIR:=$(shell pwd)
ifeq ($(OS),Windows_NT)
REPO_ROOT:=$(shell cygpath -m $(REPO_ROOT))
MAKE_DIR:=$(shell cygpath -m $(MAKE_DIR))
endif
SUBMODULES:=$(REPO_ROOT)/submodules
MAKE_FPGA:=$(SUBMODULES)/make-fpga/make-fpga.mak
