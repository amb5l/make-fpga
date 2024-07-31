################################################################################
# vivado.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
# name
# VIVADO_PART         FPGA part number
# VIVADO_LANGUAGE     VHDL or Verilog
# VIVADO_VHDL_LRM     default VHDL LRM for design and simulation sources:
#                       2000, 2008 or 2019 (default is 2008)
# VIVADO_DSN_TOP      top design unit (entity or configuration)
# VIVADO_DSN_GEN      top generics:
#                       generic=value<,generic=value...>
# VIVADO_DSN_SRC      list of design sources, each as follows:
#                       path/file<=lib><;language>
# VIVADO_BD_TCL       list of block diagram creating TCL files
# VIVADO_PROC_REF     reference (name) of block diagram containing CPU
# VIVADO_PROC_CELL    path from BD instance down to CPU for ELF association
# VIVADO_DSN_ELF      ELF to associate with CPU for builds
# VIVADO_XDC          list of constraint files, with =scope suffixes
# VIVADO_SIM_SRC      list of simulation sources (see VIVADO_DSN_SRC)
# VIVADO_SIM_RUN      list of simulation runs, each as follows:
#                       name=<lib:>unit;<generic=value<,generic=value...>>
#                       For a single run, name may be omitted and defaults to 'sim'
# VIVADO_SIM_ELF      ELF to associate with CPU for simulations
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

# defaults
vivado_default: bit
VIVADO?=vivado
VIVADO_DIR?=vivado
VIVADO_PROJ?=fpga
VIVADO_WORK?=work
VIVADO_VHDL_LRM?=2008
VIVADO_SIM_ELF?=$(VIVADO_DSN_ELF)

# checks
$(call check_defined,XILINX_VIVADO)
$(call check_option,VIVADO_LANGUAGE,VHDL Verilog)
$(call check_defined_alt,VIVADO_DSN_SRC VIVADO_SIM_SRC)
$(call check_defined_alt,VIVADO_DSN_TOP VIVADO_SIM_TOP)
$(if $(filter 1993 2000 2008 2019,$(VIVADO_VHDL_LRM)),,$(error VIVADO_VHDL_LRM value is unsupported: $(VIVADO_VHDL_LRM)))
$(foreach s,$(VIVADO_DSN_SRC) $(VIVADO_SIM_SRC),$(if $(filter 1993 2000 2008 2019,$(call get_src_lrm,$s,$(VIVADO_VHDL_LRM))),,$(error source file LRM is unsupported: $s)))

# local definitions
VIVADO_BD_SRC_DIR=$(VIVADO_PROJ).srcs/sources_1/bd
VIVADO_BD_GEN_DIR?=$(VIVADO_PROJ).gen/sources_1/bd
VIVADO_XSA=$(VIVADO_DSN_TOP).xsa
VIVADO_BIT=$(VIVADO_DSN_TOP).bit
vivado_touch_dir=$(VIVADO_DIR)/touch
$(if $(filter dev,$(MAKECMDGOALS)),$(eval dev=1))

# functions
vivado_run    = @cd $(VIVADO_DIR) && $(VIVADO) -mode tcl -notrace -nolog -nojournal -source $(subst _tcl,.tcl,$1) $(addprefix -tclargs ,$2)
get_xdc_file  = $(foreach x,$1,$(word 1,$(subst =, ,$x)))
get_xdc_scope = $(strip $(foreach x,$1,$(word 2,$(subst =, ,$x))))
get_bd_file   = $(word 1,$(subst =, ,$x))
get_bd_args   = $(word 2,$(subst =, ,$x))

# simulation checks and adjustments
ifneq (,$(VIVADO_SIM_RUN))
ifneq (1,$(words $(VIVADO_SIM_RUN)))
$(foreach r,$(VIVADO_SIM_RUN),$(if $(findstring =,$(word 1,$(subst ;, ,$r))),,$(error Multiple simulation runs must be named)))
else
$(if $(findstring =,$(word 1,$(subst ;, ,$(VIVADO_SIM_RUN)))),,$(eval VIVADO_SIM_RUN=sim=$(value VIVADO_SIM_RUN)))
endif
VIVADO_SIM_RUN_NAME=$(call get_run_name,$(VIVADO_SIM_RUN))
else
ifneq (,$(strip $(VIVADO_SIM_SRC)))
$(info Note: VIVADO_SIM_SRC is defined but VIVADO_SIM_RUN is not)
endif
endif

# constraints
$(foreach x,$(VIVADO_XDC),$(if $(call get_xdc_scope,$x),,$(error All constraints must be scoped)))
VIVADO_XDC_SYNTH=$(foreach x,$(VIVADO_XDC),$(if,$(findstring SYNTH,$(call get_xdc_scope,$x)),$(call get_xdc_file,$x)))
VIVADO_XDC_IMPL=$(foreach x,$(VIVADO_XDC),$(if,$(findstring IMPL,$(call get_xdc_scope,$x)),$(call get_xdc_file,$x)))
VIVADO_XDC_SIM=$(foreach x,$(VIVADO_XDC),$(if,$(findstring SIM,$(call get_xdc_scope,$x)),$(call get_xdc_file,$x)))

################################################################################
# TCL sequences
# TODO: use TCL variables to hold makefile variables (for clarity in script files)

vivado_scripts+=vivado_xpr_tcl
define vivado_xpr_tcl
	create_project $(if $(VIVADO_PART),-part "$(VIVADO_PART)") -force "$(VIVADO_PROJ)"
	if {"$(VIVADO_SIM_RUN_NAME)" != ""} {
		puts "adding simulation filesets..."
		foreach r {$(VIVADO_SIM_RUN_NAME)} {
			if {!("$$r" in [get_filesets])} {
				create_fileset -simset $$r
			}
			set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets $$r]
		}
		current_fileset -simset [get_filesets $(word 1,$(VIVADO_SIM_RUN_NAME))]
		foreach s [get_filesets] {
			if {$$s != "sources_1" && $$s != "constrs_1" && $$s != "utils_1"} {
				if {!("$$s" in {$(VIVADO_SIM_RUN_NAME)})} {
					delete_fileset $$s
				}
			}
		}
	}
	puts "setting part..."
	if {"$(VIVADO_PART)" != ""} {
		if {[get_property part [current_project]] != "$(VIVADO_PART)"} {
			set_property part "$(VIVADO_PART)" [current_project]
		}
	}
	puts "setting target language..."
	set_property target_language "$(VIVADO_LANGUAGE)" [current_project]
	proc lib_type {s fs} {
		set f [lindex [split "$$s" "=;"] 0]
		if {[string first "=" $$s] != -1} {
			set l [lindex [split "$$s" "=;"] 1]
		} else {
			set l "$(VIVADO_WORK)"
		}
		set_property library $$l [get_files -of_objects [get_filesets $$fs] $$f]
		if {[string first ";" $$s] != -1} {
			set lang [string map {"-" " "} [lindex [split "$$s" ";"] 1]]
			if {$$lang == "VHDL 2000"} {
				set lang "VHDL"
			}
			set_property file_type $$lang [get_files -of_objects [get_filesets $$fs] $$f]
		} elseif {[string match .vh* [file extension $$f]]} {
			set lang [get_property file_type [get_files -of_objects [get_filesets $$fs] $$f]]
			if {[string match VHDL* $$lang]} {
				set lang "VHDL"
				if {"$(VIVADO_VHDL_LRM)" != "2000"} {
					set lang "VHDL $(VIVADO_VHDL_LRM)"
				}
			}
			set_property file_type "$$lang" [get_files -of_objects [get_filesets $$fs] $$f]
		}
	}
	if {"$(VIVADO_DSN_SRC)" != ""} {
		puts "adding design sources..."
		add_files -norecurse -fileset [get_filesets sources_1] {$(call get_src_file,$(VIVADO_DSN_SRC))}
		puts "assigning design sources to libraries, and language defaults/overrides..."
		foreach s {$(VIVADO_DSN_SRC)} {
			lib_type $$s sources_1
		}
	}
	if {"$(VIVADO_SIM_SRC)" != ""} {
		puts "adding simulation sources..."
		foreach r {$(VIVADO_SIM_RUN_NAME)} {
			add_files -norecurse -fileset [get_filesets $$r] {$(call get_src_file,$(VIVADO_SIM_SRC))}
		}
		puts "assigning simulation sources to libraries, and language defaults/overrides..."
		foreach r {$(VIVADO_SIM_RUN_NAME)} {
			foreach s {$(VIVADO_SIM_SRC)} {
				lib_type $$s $$r
			}
		}
	}
	if {"$(VIVADO_DSN_TOP)" != ""} {
		puts "setting top design unit..."
		set_property top "$(VIVADO_DSN_TOP)" [get_filesets sources_1]
	}
	if {[llength {$(VIVADO_DSN_GEN)}] > 0} {
		puts "setting top design unit generics..."
		set_property generic {$(VIVADO_DSN_GEN)} [get_filesets sources_1]
	}
	if {"$(VIVADO_SIM_RUN_NAME)" != ""} {
		puts "setting top unit and generics for simulation filesets..."
		foreach r {$(VIVADO_SIM_RUN)} {
			set run [lindex [split "$$r" "="] 0]
			set unit [lindex [split "$$r" "=;"] 1]
			if {[string first ":" $$unit] != -1} {
				set unit [lindex [split "$$unit" ":"] 1]
			}
			set gen [split [lindex [split "$$r" ";"] 1] ","]
			set_property top $$unit [get_filesets $$run]
			if {[llength $$gen] > 0} {
				set_property generic $$gen [get_filesets $$run]
			}
		}
	}
	puts "enabling synthesis assertions..."
	set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]
	proc scope_constrs {xdc} {
		foreach x $$xdc {
			set file  [lindex [split "$$x" "="] 0]
			set scope [lindex [split "$$x" "="] 1]
			set_property used_in_synthesis      [expr [string first "SYNTH" "$$scope"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] $$file]
			set_property used_in_implementation [expr [string first "IMPL"  "$$scope"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] $$file]
			if {[file extension $$file] == ".tcl"} {
				set_property used_in_simulation     [expr [string first "SIM"   "$$scope"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] $$file]
			}
		}
	}
	if {"$(VIVADO_XDC)" != ""} {
		puts "adding constraints..."
		add_files -norecurse -fileset [get_filesets constrs_1] {$(call get_xdc_file,$(VIVADO_XDC))}
		puts "scoping constraints..."
		scope_constrs {$(VIVADO_XDC)}
	}
	exit 0
endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_bd_tcl
define vivado_bd_tcl
	set file [lindex $$argv 0]
	set args [lrange $$argv 1 end]
	set design [file rootname [file tail $$file]]
	open_project $(VIVADO_PROJ)
	if {[get_files -quiet -of_objects [get_filesets sources_1] "$$design.bd"] != ""} {
		export_ip_user_files -of_objects [get_files -of_objects [get_filesets sources_1] "$$design.bd"] -no_script -reset -force -quiet
		remove_files [get_files -of_objects [get_filesets sources_1] "$$design.bd"]
		file delete -force $(VIVADO_BD_SRC_DIR)/$$design
		file delete -force $(VIVADO_BD_GEN_DIR)/$$design
	}
	set argv $$args
	set argc [llength $$argv]
	source $$file
endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_bd_gen_tcl
define vivado_bd_gen_tcl
	set f [lindex $$argv 0]
	open_project $(VIVADO_PROJ)
	generate_target all [get_files -of_objects [get_filesets sources_1] [file tail $$f]]
endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_xsa_tcl
define vivado_xsa_tcl
	open_project $(VIVADO_PROJ)
	write_hw_platform -fixed -force -file $(VIVADO_DSN_TOP).xsa
endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_dsn_elf_tcl
define vivado_dsn_elf_tcl
	set f [lindex $$argv 0]
	open_project $(VIVADO_PROJ)
	add_files -norecurse -fileset [get_filesets sources_1] $$f
	set_property used_in_implementation 1 [get_files -of_objects [get_filesets sources_1] $$f]
	set_property used_in_simulation 0 [get_files -of_objects [get_filesets sources_1] $$f]
	set_property SCOPED_TO_REF {$(VIVADO_PROC_REF)} [get_files -of_objects [get_fileset sources_1] $$f]
	set_property SCOPED_TO_CELLS {$(VIVADO_PROC_CELL)} [get_files -of_objects [get_fileset sources_1] $$f]
endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_sim_elf_tcl
define vivado_sim_elf_tcl
	set run [lindex $$argv 0]
	set f   [lindex $$argv 1]
	open_project $(VIVADO_PROJ)
	add_files -norecurse -fileset [get_filesets $$run] $$f
	set_property used_in_simulation 1 [get_files -of_objects [get_filesets $$run] $$f]
	set_property SCOPED_TO_REF {$(VIVADO_PROC_REF)} [get_files -of_objects [get_fileset $$run] $$f]
	set_property SCOPED_TO_CELLS {$(VIVADO_PROC_CELL)} [get_files -of_objects [get_fileset $$run] $$f]
endef


#-------------------------------------------------------------------------------

vivado_scripts+=vivado_synth_tcl
define vivado_synth_tcl
	open_project $(VIVADO_PROJ)
	reset_run synth_1
	launch_runs synth_1
	wait_on_run synth_1
	if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {exit 1}
endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_impl_tcl
define vivado_impl_tcl
	open_project $(VIVADO_PROJ)
	reset_run impl_1
	launch_runs impl_1 -to_step route_design
	wait_on_run impl_1
	if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {exit 1}
endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_bit_tcl
define vivado_bit_tcl
	open_project $(VIVADO_PROJ)
	open_run impl_1
	write_bitstream -force [lindex $$argv 0]
endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_prog_tcl
define vivado_prog_tcl

	set file    [lindex $$argv 0]
	set hw_spec [lindex $$argv 1]
	set hw_interface 0
	set hw_device 0
	if {$$hw_spec != ""} {
		if {[string first . $$hw_spec] != -1} {
			set hw_spec_list [split $$hw_spec .]
			set hw_interface [lindex $$hw_spec_list 0]
			set hw_device [lindex $$hw_spec_list 1]
		} else {
			set hw_interface $$hw_spec
		}
	}
	open_hw_manager
	connect_hw_server
	set hw_interface_list [get_hw_targets]
	puts "-------------------------------------------------------------------------------"
	puts "interfaces:"
	for {set x 0} {$$x < [llength $$hw_interface_list]} {incr x} {
		puts "  $$x: [lindex $$hw_interface_list $$x]"
	}
	puts "opening interface $$hw_interface: [lindex $$hw_interface_list $$hw_interface]"
	open_hw_target -quiet [lindex $$hw_interface_list $$hw_interface]
	set hw_device_list [get_hw_devices]
	puts "devices:"
	for {set x 0} {$$x < [llength $$hw_device_list]} {incr x} {
		puts "  $$x: [lindex $$hw_device_list $$x]"
	}
	puts "programming device $$hw_device: [lindex $$hw_device_list $$hw_device]"
	puts "-------------------------------------------------------------------------------"
	current_hw_device [lindex $$hw_device_list $$hw_device]
	set_property PROGRAM.FILE $$file [current_hw_device]
	program_hw_devices [current_hw_device]

endef

#-------------------------------------------------------------------------------

vivado_scripts+=vivado_sim_tcl
define vivado_sim_tcl

	set r [lindex $$argv 0]
	open_project $(VIVADO_PROJ)
	current_fileset -simset [get_filesets $$r]
	launch_simulation
	run all

endef

################################################################################
# write script files

$(shell $(MKDIR) -p $(VIVADO_DIR))
$(foreach s,$(vivado_scripts),\
	$(file >$(VIVADO_DIR)/$(subst _tcl,.tcl,$s),set code [catch { $($s) } result]; puts $$result; exit $$code) \
)

################################################################################
# Vivado rules and recipes

.PHONY: dev vivado_default vivado_force xpr bd hwdef xsa synth dsn_elf impl bit sim_elf sim_bat sim_gui

dev::
	@:

vivado_force:

# project directory
$(VIVADO_DIR):
	@$(MKDIR) -p $@"

# touch directory
$(vivado_touch_dir):
	@$(MKDIR) -p $@

# create project file
$(vivado_touch_dir)/$(VIVADO_PROJ).xpr: $(if $(filter dev,$(MAKECMDGOALS)),,$(MAKEFILE_LIST)) | $(VIVADO_DIR) $(vivado_touch_dir)
	$(call banner,Vivado: create project)
	@rm -f $(VIVADO_DIR)/$(VIVADO_PROJ).xpr
	$(call vivado_run,vivado_xpr_tcl)
	@touch $@
xpr: $(vivado_touch_dir)/$(VIVADO_PROJ).xpr

# create block diagrams
define RR_VIVADO_BD
$$(vivado_touch_dir)/$$(basename $$(notdir $$(call get_bd_file,$1))).bd: $$(call get_bd_file,$1) $$(vivado_touch_dir)/$$(VIVADO_PROJ).xpr
	$$(call banner,Vivado: create block diagram)
	$$(call vivado_run,vivado_bd_tcl,$1)
	@touch $$@
bd:: $$(vivado_touch_dir)/$$(basename $$(notdir $$(call get_bd_file,$1))).bd
endef
$(foreach x,$(VIVADO_BD_TCL),$(eval $(call RR_VIVADO_BD,$(call get_bd_file,$x) $(call get_bd_args,$x))))

# generate block diagram products
define RR_VIVADO_BD_GEN
$(vivado_touch_dir)/$(basename $(notdir $(call get_bd_file,$1))).gen: $(vivado_touch_dir)/$(basename $(notdir $(call get_bd_file,$1))).bd
	$$(call banner,Vivado: generate block diagram products)
	$$(call vivado_run,vivado_bd_gen_tcl,$(basename $(notdir $(call get_bd_file,$1))).bd)
	@touch $$@
gen:: $(vivado_touch_dir)/$(basename $(notdir $(call get_bd_file,$1))).gen
endef
$(foreach x,$(VIVADO_BD_TCL),$(eval $(call RR_VIVADO_BD_GEN,$x)))

# generate hardware handoff (XSA) file
$(vivado_touch_dir)/$(VIVADO_PROJ).xsa: $(foreach x,$(VIVADO_BD_TCL),$(addprefix $(vivado_touch_dir)/,$(basename $(notdir $(call get_bd_file,$x))).gen))
	$(call banner,Vivado: create hardware handoff (XSA) file)
	$(call vivado_run,vivado_xsa_tcl)
	@touch $@
xsa: $(vivado_touch_dir)/$(VIVADO_PROJ).xsa

# synthesis
$(vivado_touch_dir)/$(VIVADO_PROJ).synth: $(call get_src_file,$(VIVADO_DSN_SRC.$l)) $(call get_xdc_file,$(VIVADO_XDC_SYNTH)) $(foreach x,$(VIVADO_BD_TCL),$(addprefix $(vivado_touch_dir)/,$(basename $(notdir $(call get_bd_file,$x))).gen)) $(vivado_touch_dir)/$(VIVADO_PROJ).xpr
	$(call banner,Vivado: synthesis)
	$(call vivado_run,vivado_synth_tcl)
	@touch $@
synth: $(vivado_touch_dir)/$(VIVADO_PROJ).synth

# associate design ELF file
$(vivado_touch_dir)/dsn.elf: $(VIVADO_DSN_ELF) $(vivado_touch_dir)/$(VIVADO_PROJ).xpr
	$(call banner,Vivado: associate design ELF file)
	$(call vivado_run,vivado_dsn_elf_tcl,$(abspath $<))
	@touch $@
dsn_elf: $(vivado_touch_dir)/dsn.elf

# implementation (place and route) and preparation for simulation
$(vivado_touch_dir)/$(VIVADO_PROJ).impl: $(vivado_touch_dir)/$(VIVADO_PROJ).synth $(call get_xdc_file,$(VIVADO_XDC_IMPL)) $(if $(VITIS_APP),$(vivado_touch_dir)/dsn.elf)
	$(call banner,Vivado: implementation)
	$(call vivado_run,vivado_impl_tcl)
	@touch $@
impl: $(vivado_touch_dir)/$(VIVADO_PROJ).impl

# write bitstream
$(vivado_touch_dir)/$(VIVADO_PROJ).bit: $(vivado_touch_dir)/$(VIVADO_PROJ).impl
	$(call banner,Vivado: write bitstream)
	$(call vivado_run,vivado_bit_tcl,$(abspath $(VIVADO_BIT)))
	@touch $@
bit: $(vivado_touch_dir)/$(VIVADO_PROJ).bit

# program
prog: vivado_force $(vivado_touch_dir)/$(VIVADO_PROJ).bit
	$(call banner,Vivado: program)
	$(call vivado_run,vivado_prog_tcl,$(abspath $(VIVADO_BIT)))

# associate simulation ELF files
define rr_simelf
$(vivado_touch_dir)/sim_$1.elf: $(VIVADO_SIM_ELF) $(vivado_touch_dir)/$(VIVADO_PROJ).xpr
	$$(call banner,Vivado: associate simulation ELF file (run: $1))
	$$(call vivado_run,vivado_sim_elf_tcl,$1 $$(abspath $$<))
	@touch $$@
endef
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(eval $(call rr_simelf,$r)))
sim_elf: $(foreach r,$(VIVADO_SIM_RUN_NAME),$(vivado_touch_dir)/sim_$r.elf)

# simulation runs
define rr_simrun
.PHONY: sim.$1
sim.$1:: vivado_force $(vivado_touch_dir)/$(VIVADO_PROJ).xpr $(if $(VITIS_APP),$(vivado_touch_dir)/sim_$1.elf)
	$(call banner,Vivado: simulation run = $1)
	$(call vivado_run,vivado_sim_tcl,$1)
endef
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(eval $(call rr_simrun,$r)))

# batch simulation
sim_bat:: $(foreach r,$(VIVADO_SIM_RUN_NAME),sim.$r)
	@:

# interactive simulation
sim_gui:: $(vivado_touch_dir)/$(VIVADO_PROJ).xpr $(foreach x,$(VIVADO_BD_TCL),$(vivado_touch_dir)/$(basename $(notdir $(call get_bd_file,$x))).gen) $(if $(VITIS_APP),$(foreach r,$(VIVADO_SIM_RUN_NAME),$(vivado_touch_dir)/sim_$r.elf))
	vivado $(VIVADO_DIR)/$(VIVADO_PROJ).xpr

################################################################################
# Visual Studio Code
# TODO remove redundant files

VSCODE_DIR=vscode/vivado
VSCODE_TOP=$(VIVADO_DSN_TOP) $(call nodup,$(call get_run_unit,$(VIVADO_SIM_RUN)))
VSCODE_SRC=$(VIVADO_DSN_SRC) $(VIVADO_SIM_SRC) $(VIVADO_LIB_SRC)
VSCODE_LIB=$(call nodup,$(call get_src_lib,$(VSCODE_SRC),$(VIVADO_WORK)))
$(foreach l,$(VSCODE_LIB), \
	$(foreach s,$(VSCODE_SRC), \
		$(if $(filter $l,$(call get_src_lib,$s,$(VIVADO_WORK))), \
			$(eval VSCODE_SRC.$l+=$(call get_src_file,$s)) \
		) \
	) \
)
VSCODE_AUX=\
	$(call get_bd_file,$(VIVADO_BD_TCL)) \
	$(call get_xdc_file,$(VIVADO_XDC))

# workspace directory
$(VSCODE_DIR):
	@$(MKDIR) -p $@

# library directory(s) containing symbolic link(s) to source(s)
$(foreach l,$(VSCODE_LIB),$(eval $l: $(addprefix $$(VSCODE_DIR)/$l/,$(notdir $(VSCODE_SRC.$l)))))

# symbolic links to source files
define rr_srclink
$$(VSCODE_DIR)/$1/$(notdir $2): $2
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),$(eval $(call rr_srclink,$l,$s))))

# symbolic links to auxilliary text files
define rr_auxlink
$$(VSCODE_DIR)/$(notdir $1): $1
	@$$(MKDIR) -p $$(@D) && rm -f $$@
	@$$(call create_symlink,$$@,$$<)
endef
$(foreach a,$(VSCODE_AUX),$(eval $(call rr_auxlink,$a)))

# V4P configuration file
$(VSCODE_DIR)/config.v4p: vivado_force $(VSCODE_LIB)
	@printf "[libraries]\n" > $@
	$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),@printf "$l/$(notdir $s)=$l\n" >> $@$(newline)))
	@printf "[settings]\n" >> $@
	@printf "V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(strip $(VSCODE_TOP)))\n" >> $@

edit:: $(VSCODE_DIR)/config.v4p $(addprefix $(VSCODE_DIR)/,$(VSCODE_LIB)) $(addprefix $(VSCODE_DIR)/,$(notdir $(VSCODE_AUX)))
ifeq ($(OS),Windows_NT)
	@cd $(VSCODE_DIR) && start code .
else
	@cd $(VSCODE_DIR) && code . &
endif
################################################################################

clean::
	@rm -rf $(VIVADO_DIR)
