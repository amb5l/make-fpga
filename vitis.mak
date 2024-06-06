################################################################################
# vitis.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# TODO:
#	version check
#	Linux test

################################################################################
# Common
################################################################################

# XILINX_VITIS must contain the path to the Vitis installation
$(call check_defined,XILINX_VITIS)
XILINX_VITIS:=$(call xpath,$(XILINX_VITIS))
$(call check_defined,VITIS_FLOW)

# checks
ifndef VITIS_FLOW
$(error VITIS_FLOW must be defined)
endif

# defaults
VITIS_DIR?=vitis
VITIS_APP?=app
nomakefiledeps?=false

# local definitions
makefiledeps=$(if,$(filter true,$(nomakefiledeps),,$(MAKEFILE_LIST))

################################################################################
# Classic Flow
################################################################################

ifeq (classic,$(VITIS_FLOW))

# defaults
XSCT?=xsct
VITIS_ELF_RLS?=$(VITIS_APP)/Release/$(VITIS_APP).elf
VITIS_ELF_DBG?=$(VITIS_APP)/Debug/$(VITIS_APP).elf

# local definitions
XSCT_RUN_TCL=run.tcl
define XSCT_RUN
	$(file >$(VITIS_DIR)/$(XSCT_RUN_TCL),set code [catch { $($1) } result]; puts $$result; exit $$code)
	@cd $(VITIS_DIR) && $(XSCT) $(XSCT_RUN_TCL) $2
endef
VITIS_PRJ=$(VITIS_APP)/.project

################################################################################
# TCL sequences

define xsct_tcl_prj

	setws .
	set proc [getprocessors ../$(VIVADO_DIR)/$(VIVADO_XSA)]
	puts "creating Vitis Classic project..."
	app create -name $(VITIS_APP) -hw ../$(VIVADO_DIR)/$(VIVADO_XSA) -os standalone -proc $$proc -template {Empty Application(C)}
	set x [list "	<linkedResources>"]
	puts "adding sources..."
	foreach filename {$(VITIS_SRC)} {
		set basename [file tail $$filename]
		set relpath [fileutil::relative [file normalize ./$(VITIS_APP)] $$filename]
		set n 0
		while {[string range $$relpath 0 2] == "../"} {
			set relpath [string range $$relpath 3 end]
			incr n
		}
		if {n > 0} {
			set relpath "PARENT-$$n-PROJECT_LOC/$$relpath"
		}
		set s [list "		<link>"]
		lappend s "			<name>src/$$basename</name>"
		lappend s "			<type>1</type>"
		lappend s "			<locationURI>$$relpath</locationURI>"
		lappend s "		</link>"
		set x [concat $$x $$s]
	}
	lappend x "	</linkedResources>"
	set f [open "$(VITIS_PRJ)" "r"]
	set lines [split [read $$f] "\n"]
	close $$f
	set i [lsearch $$lines "	</natures>"]
	if {$$i < 0} {
		error "did not find insertion point"
	}
	set lines [linsert $$lines 1+$$i {*}$$x]
	set f [open "$(VITIS_PRJ)" "w"]
	puts $$f [join $$lines "\n"]
	close $$f

endef

#-------------------------------------------------------------------------------

define xsct_tcl_elf

	set c [lindex $$argv 0]
	setws .
	app config -name $(VITIS_APP) build-config $$c
	app build -name $(VITIS_APP)

endef

################################################################################
# rules and recipes

# workspace directory
$(VITIS_DIR):
	@bash -c "mkdir -p $@"

# project
.SECONDEXPANSION:
$(VITIS_DIR)/$(VITIS_PRJ): $$(vivado_touch_dir)/$$(VIVADO_PROJ).xsa $(makefiledeps) | $(VITIS_DIR)
	$(call banner,Vitis Classic: create project)
	@bash -c "\
		cd $(VITIS_DIR) && \
		find . -type f -not \( -name '$(XSCT_RUN_TCL)' \) -delete && \
		find . -type d -not \( -name '.' -or -name '..' \) -exec rm -rf {} + \
	"
	$(call XSCT_RUN,xsct_tcl_prj)

# release ELF
$(VITIS_DIR)/$(VITIS_ELF_RLS): $(VITIS_SRC) $(VITIS_DIR)/$(VITIS_PRJ)
	$(call banner,Vitis Classic: build release ELF)
	$(call XSCT_RUN,xsct_tcl_elf,Release)

# debug ELF
$(VITIS_DIR)/$(VITIS_ELF_DBG): $(VITIS_SRC) | $(VITIS_DIR)/$(VITIS_PRJ)
	$(call banner,Vitis Classic: build debug ELF)
	$(call XSCT_RUN,xsct_tcl_elf,Debug)

################################################################################
# goals

.PHONY: vitis_force prj rls dbg elf

vitis_force:

prj: $(VITIS_DIR)/$(VITIS_PRJ)

rls: $(VITIS_DIR)/$(VITIS_ELF_RLS)

dbg: $(VITIS_DIR)/$(VITIS_ELF_DBG)

elf: rls dbg

################################################################################
# Unified Flow
################################################################################

else

$(error Unsupported flow: $(VITIS_FLOW))

################################################################################

endif

clean::
	@rm -rf $(VITIS_DIR)
