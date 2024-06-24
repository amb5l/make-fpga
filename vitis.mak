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
		find . -maxdepth 1 -type d -not \( -name '$(VITIS_APP)' -or -name '.' -or -name '..' \) -exec rm -rf {} + && \
		if [ -d ./$(VITIS_APP)/Release ]; then \
			find ./$(VITIS_APP)/Release -type f -delete && \
			find ./$(VITIS_APP)/Release -maxdepth 1 -type d -not \( -wholename './$(VITIS_APP)/Release' -or -wholename './$(VITIS_APP)/Release/vscode' -or -name '.' -or -name '..' \) -exec rm -rf {} +; \
		fi && \
		if [ -d ./$(VITIS_APP)/Debug ]; then \
			find ./$(VITIS_APP)/Debug -type f -delete && \
			find ./$(VITIS_APP)/Debug -maxdepth 1 -type d -not \( -wholename './$(VITIS_APP)/Debug' -or -wholename './$(VITIS_APP)/Debug/vscode' -or -name '.' -or -name '..' \) -exec rm -rf {} +; \
		fi && \
		if [ -d ./$(VITIS_APP) ]; then \
			find ./$(VITIS_APP) -type f -delete && \
			find ./$(VITIS_APP) -maxdepth 1 -type d -not \( -wholename './$(VITIS_APP)' -or -wholename './$(VITIS_APP)/Release' -or -wholename './$(VITIS_APP)/Release/vscode' -or -wholename './$(VITIS_APP)/Debug' -or -wholename './$(VITIS_APP)/Debug/vscode' -or -name 'Debug' -or -name '.' -or -name '..' \) -exec rm -rf {} +; \
		fi \
	"
	$(call XSCT_RUN,xsct_tcl_prj,$(abspath $(VIVADO_DIR)/$(VIVADO_XSA)))

# release ELF
$(VITIS_DIR)/$(VITIS_ELF_RLS): $(VITIS_SRC) $(VITIS_DIR)/$(VITIS_PRJ)
	$(call banner,Vitis Classic: build release ELF)
	@rm -f $@
	$(call XSCT_RUN,xsct_tcl_elf,Release)
	@bash -c "if [ -f $@ ]; \
	then echo \"Success\"; \
	else echo \"Failed to build ELF\"; exit 1; \
	fi"

# debug ELF
$(VITIS_DIR)/$(VITIS_ELF_DBG): $(VITIS_SRC) | $(VITIS_DIR)/$(VITIS_PRJ)
	$(call banner,Vitis Classic: build debug ELF)
	@rm -f $@
	$(call XSCT_RUN,xsct_tcl_elf,Debug)
	@bash -c "if [ -f $@ ]; \
	then echo \"Success\"; \
	else echo \"Failed to build ELF\"; exit 1; \
	fi"

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

VSCODE_DIR_RLS=$(VITIS_DIR)/$(VITIS_APP)/Release/vscode
VSCODE_DIR_DBG=$(VITIS_DIR)/$(VITIS_APP)/Debug/vscode
VSCODE_SRC=$(VITIS_SRC)

# workspace directories
$(VSCODE_DIR_RLS):
	@bash -c "mkdir -p $@"
$(VSCODE_DIR_RLS)/.vscode:
	@bash -c "mkdir -p $@"
$(VSCODE_DIR_DBG):
	@bash -c "mkdir -p $@"
$(VSCODE_DIR_DBG)/.vscode:
	@bash -c "mkdir -p $@"

# source directory, containing symbolic link(s) to source(s)
$(VSCODE_DIR_RLS)/src: $(addprefix $$(VSCODE_DIR_RLS)/src/,$(notdir $(VSCODE_SRC)))
$(VSCODE_DIR_DBG)/src: $(addprefix $$(VSCODE_DIR_DBG)/src/,$(notdir $(VSCODE_SRC)))

# symbolic links to source files
ifeq ($(OS),Windows_NT)
define rr_srclink
$$(VSCODE_DIR_RLS)/src/$(notdir $1): $1
	@bash -c "mkdir -p $$(@D) && rm -f $$@"
	@bash -c "cmd.exe //C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
$$(VSCODE_DIR_DBG)/src/$(notdir $1): $1
	@bash -c "mkdir -p $$(@D) && rm -f $$@"
	@bash -c "cmd.exe //C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
endef
else
define rr_srclink
$$(VSCODE_DIR_RLS)/$1/$(notdir $1): $1
	@mkdir -p $$(@D)
	@ln $$< $$@
$$(VSCODE_DIR_DBG)/$1/$(notdir $1): $1
	@mkdir -p $$(@D)
	@ln $$< $$@
endef
endif
$(foreach s,$(VSCODE_SRC),$(eval $(call rr_srclink,$s)))

define settings_rls
{
    "configurations": [
        {
            "name": "Vitis",
            "includePath": [
				$(foreach i,$(VITIS_INC),"$i",)
                "$(XILINX_VITIS)\\gnu\\$(if $(filter mbv,$(CPU)),riscv,microblaze)\\**\\*xilinx-elf)\\usr\\include",
                "$${workspaceFolder}\\..\\..\\..\\*\\*\\standalone_domain\\bsp\\*\\include"
            ],
            "defines": [
				$(foreach s,$(VITIS_SYM) $(VITIS_SYM_RLS),"$s",)
            ],
            "compilerPath": "$(XILINX_VITIS)\\gnu\\$(if $(filter mbv,$(CPU)),riscv\\nt\\riscv64-unknown-elf\\bin\\riscv64-unknown-elf-gcc,microblaze\\nt\\bin\\mb-gcc).exe",
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
                "$(XILINX_VITIS)\\gnu\\$(if $(filter mbv,$(CPU)),riscv,microblaze)\\**\\*xilinx-elf)\\usr\\include",
                "$${workspaceFolder}\\..\\..\\..\\*\\*\\standalone_domain\\bsp\\*\\include"
            ],
            "defines": [
				$(foreach s,$(VITIS_SYM) $(VITIS_SYM_DBG),"$s",)
            ],
            "compilerPath": "$(XILINX_VITIS)\\gnu\\$(if $(filter mbv,$(CPU)),riscv\\nt\\riscv64-unknown-elf\\bin\\riscv64-unknown-elf-gcc,microblaze\\nt\\bin\\mb-gcc).exe",
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
	@cd $(VSCODE_DIR_RLS) && touch Release && code .
edit:: $(VSCODE_DIR_DBG)/.vscode/c_cpp_properties.json $(VSCODE_DIR_DBG)/src
	@cd $(VSCODE_DIR_DBG) && touch Debug && code .

################################################################################

clean::
	@rm -rf $(VITIS_DIR)
