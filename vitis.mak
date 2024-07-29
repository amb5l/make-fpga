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

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

# checks
$(call check_defined,XILINX_VITIS)
$(call check_defined,VITIS_FLOW)
$(call check_defined,VITIS_SRC)

# defaults
VITIS_DIR?=vitis
VITIS_APP?=app

################################################################################
# Classic Flow
################################################################################

ifeq (classic,$(VITIS_FLOW))

# defaults
XSCT?=xsct
VITIS_PRJ=$(VITIS_APP)/.project
VITIS_ELF_RLS?=$(VITIS_APP)/Release/$(VITIS_APP).elf
VITIS_ELF_DBG?=$(VITIS_APP)/Debug/$(VITIS_APP).elf

# functions
xsct_run=@cd $(VITIS_DIR) && $(XSCT) $(subst _tcl,.tcl,$1) $2

################################################################################
# TCL sequences
# TODO: use TCL variables to hold makefile variables (for clarity in script files)

xsct_scripts+=xsct_prj_tcl
define xsct_prj_tcl

	set xsa [lindex $$argv 0]
	setws .
	set proc [getprocessors $$xsa]
	puts "creating Vitis Classic project..."
	app create -name $(VITIS_APP) -hw $$xsa -os standalone -proc $$proc -template {Empty Application(C)}
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
	puts "setting include paths..."
	foreach p {$(VITIS_INC)} {
		app config -name $(VITIS_APP) build-config release
		app config -name $(VITIS_APP) include-path $$p
		app config -name $(VITIS_APP) build-config debug
		app config -name $(VITIS_APP) include-path $$p
	}
	puts "defining preprocessor symbols..."
	foreach s {$(VITIS_SYM)} {
		app config -name $(VITIS_APP) build-config release
		app config -name $(VITIS_APP) define-compiler-symbols $$s
		app config -name $(VITIS_APP) build-config debug
		app config -name $(VITIS_APP) define-compiler-symbols $$s
	}
	puts "defining preprocessor symbols (release specific)..."
	app config -name $(VITIS_APP) build-config release
	foreach s {$(VITIS_SYM_RLS)} {
		app config -name $(VITIS_APP) define-compiler-symbols $$s
	}
	puts "defining preprocessor symbols (debug specific)..."
	app config -name $(VITIS_APP) build-config debug
	foreach s {$(VITIS_SYM_DBG)} {
		app config -name $(VITIS_APP) define-compiler-symbols $$s
	}
	puts "regenerating BSP..."
	bsp regenerate
	puts "generating platform..."
	platform generate

endef

#-------------------------------------------------------------------------------

xsct_scripts+=xsct_elf_tcl
define xsct_elf_tcl

	set c [lindex $$argv 0]
	setws .
	app config -name $(VITIS_APP) build-config $$c
	app build -name $(VITIS_APP)

endef

################################################################################
# write script files

$(shell $(MKDIR) -p $(VITIS_DIR))
$(foreach s,$(xsct_scripts),\
	$(file >$(VITIS_DIR)/$(subst _tcl,.tcl,$s),set code [catch { $($s) } result]; puts $$result; exit $$code) \
)

################################################################################
# rules and recipes

# workspace directory
$(VITIS_DIR):
	@$(MKDIR) -p $@

# project
.SECONDEXPANSION:
$(VITIS_DIR)/$(VITIS_PRJ): $$(vivado_touch_dir)/$$(VIVADO_PROJ).xsa $(if $(filter dev,$(MAKECMDGOALS)),,$(MAKEFILE_LIST)) | $(VITIS_DIR)
	$(call banner,Vitis Classic: create project)
	@cd $(VITIS_DIR) && \
		rm -rf .metadata .Xil $(VITIS_APP) $(VITIS_APP)_system $$(VIVADO_PROJ) && \
		rm -f .analytics IDE.log
	$(call xsct_run,xsct_prj_tcl,$(abspath $(VIVADO_DIR)/$(VIVADO_XSA)))

# release ELF
$(VITIS_DIR)/$(VITIS_ELF_RLS): $(VITIS_SRC) $(VITIS_DIR)/$(VITIS_PRJ)
	$(call banner,Vitis Classic: build release ELF)
	@rm -f $@
	$(call xsct_run,xsct_elf_tcl,Release)
	@printf "Checking that ELF file has built correctly..."
	@[ -f $@ ]
	@printf "OK"

# debug ELF
$(VITIS_DIR)/$(VITIS_ELF_DBG): $(VITIS_SRC) $(VITIS_DIR)/$(VITIS_PRJ)
	$(call banner,Vitis Classic: build debug ELF)
	@rm -f $@
	$(call xsct_run,xsct_elf_tcl,Debug)
	@printf "Checking that ELF file has built correctly..."
	@[ -f $@ ]
	@printf "OK"

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

################################################################################
# Visual Studio Code
# TODO remove redundant files

VSCODE_DIR_RLS=vscode/vitis/Release
VSCODE_DIR_DBG=vscode/vitis/Debug
VSCODE_SRC=$(VITIS_SRC)

# workspace directories
$(VSCODE_DIR_RLS):
	@$(MKDIR) -p $@
$(VSCODE_DIR_RLS)/.vscode:
	@$(MKDIR) -p $@
$(VSCODE_DIR_DBG):
	@$(MKDIR) -p $@
$(VSCODE_DIR_DBG)/.vscode:
	@$(MKDIR) -p $@

# source directory, containing symbolic link(s) to source(s)
$(VSCODE_DIR_RLS)/src: $(addprefix $$(VSCODE_DIR_RLS)/src/,$(notdir $(VSCODE_SRC)))
$(VSCODE_DIR_DBG)/src: $(addprefix $$(VSCODE_DIR_DBG)/src/,$(notdir $(VSCODE_SRC)))

# symbolic links to source files
define rr_srclink
$$(VSCODE_DIR_RLS)/src/$(notdir $1): $1
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
$$(VSCODE_DIR_DBG)/src/$(notdir $1): $1
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach s,$(VSCODE_SRC),$(eval $(call rr_srclink,$s)))

define settings_rls
{
    "configurations": [
        {
            "name": "Vitis",
            "includePath": [
				$(foreach i,$(VITIS_INC),"$i",)
                "$(subst \,/,$(XILINX_VITIS))/gnu/$(if $(filter mbv,$(CPU)),riscv,microblaze)/**/*xilinx-elf/usr/include",
                "$${workspaceFolder}/../../../*/*/standalone_domain/bsp/*/include"
            ],
            "defines": [
				$(foreach s,$(VITIS_SYM) $(VITIS_SYM_RLS),"$s",)
            ],
            "compilerPath": "$(subst \,/,$(XILINX_VITIS))/gnu/$(if $(filter mbv,$(CPU)),riscv//nt//riscv64-unknown-elf//bin//riscv64-unknown-elf-gcc,microblaze//nt//bin//mb-gcc).exe",
            "cStandard": "c17",
            "cppStandard": "gnu++17",
            "intelliSenseMode": "windows-gcc-x64"
        }
    ],
    "version": 4
}
endef

define settings_dbg
{
    "configurations": [
        {
            "name": "Vitis",
            "includePath": [
				$(foreach i,$(VITIS_INC),"$i",)
                "$(subst \,/,$(XILINX_VITIS))/gnu/$(if $(filter mbv,$(CPU)),riscv,microblaze)/**/*xilinx-elf)/usr/include",
                "$${workspaceFolder}/../../../*/*/standalone_domain/bsp/*/include"
            ],
            "defines": [
				$(foreach s,$(VITIS_SYM) $(VITIS_SYM_DBG),"$s",)
            ],
            "compilerPath": "$(subst \,/,$(XILINX_VITIS))/gnu/$(if $(filter mbv,$(CPU)),riscv/nt/riscv64-unknown-elf/bin/riscv64-unknown-elf-gcc,microblaze/nt/bin/mb-gcc).exe",
            "cStandard": "c17",
            "cppStandard": "gnu++17",
            "intelliSenseMode": "windows-gcc-x64"
        }
    ],
    "version": 4
}
endef

$(VSCODE_DIR_RLS)/.vscode/c_cpp_properties.json: vitis_force | $(VSCODE_DIR_RLS)/.vscode
	$(file >$@,$(settings_rls))
$(VSCODE_DIR_DBG)/.vscode/c_cpp_properties.json: vitis_force | $(VSCODE_DIR_DBG)/.vscode
	$(file >$@,$(settings_dbg))

edit:: $(VSCODE_DIR_RLS)/.vscode/c_cpp_properties.json $(VSCODE_DIR_RLS)/src
ifeq ($(OS),Windows_NT)
	@cd $(VSCODE_DIR_RLS) && start code .
else
	@cd $(VSCODE_DIR_RLS) && code . &
endif
edit:: $(VSCODE_DIR_DBG)/.vscode/c_cpp_properties.json $(VSCODE_DIR_DBG)/src
ifeq ($(OS),Windows_NT)
	@cd $(VSCODE_DIR_DBG) && start code .
else
	@cd $(VSCODE_DIR_DBG) && code . &
endif

################################################################################

clean::
	@rm -rf $(VITIS_DIR)
