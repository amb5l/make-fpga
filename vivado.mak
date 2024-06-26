################################################################################
# vivado.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# TODO:
#	execute simulation runs
#	design generics
#	ELF/CPU support
#	timing simulation
#	programming
################################################################################
# User makefile variables:
# name
# VIVADO_PART         FPGA part number
# VIVADO_LANGUAGE     VHDL-1993, VHDL-2008 or Verilog
# VIVADO_DSN_TOP      name of top design unit (entity or configuration)
# VIVADO_DSN_GEN      top generics
# VIVADO_DSN_LIB      list of design libraries (defaults to 'work')
# VIVADO_DSN_SRC      list of design source files, with optional =language suffix
# VIVADO_DSN_SRC.l    as above, specific to library l
# VIVADO_SIM_LIB      list of simulation libraries (defaults to 'work')
# VIVADO_SIM_SRC      additional sources for simulation e.g. testbench
# VIVADO_SIM_SRC.l    as above, specific to library l
# VIVADO_SIM_SRC.l.r  as above, specific to run r
# VIVADO_BD_TCL       list of block diagram creating TCL files
# VIVADO_PROC_REF     reference (name) of block diagram containing CPU
# VIVADO_PROC_CELL    path from BD instance down to CPU for ELF association
# VIVADO_DSN_ELF      ELF to associate with CPU for builds
# VIVADO_SIM_ELF      default ELF to associate with CPU for simulations
# VIVADO_SIM_RUN      list of simulation runs, each as follows:
#                      <name:>top<;generic=value<,generic=value...>>
#                      For a single run, name may be omitted and defaults to 'sim'
# VIVADO_XDC          list of constraint files, with =scope suffixes
#
# Notes
# 1. If VIVADO_DSN_LIB is defined, sources must be defined by VIVADO_DSN_SRC.l
# 2. Similarly for VIVADO_SIM_LIB, except run specific defs are allowed.
################################################################################

# XILINX_VIVADO must contain the path to the Vivado installation
$(call check_defined,XILINX_VIVADO)
XILINX_VIVADO:=$(call xpath,$(XILINX_VIVADO))

# defaults
VIVADO?=vivado
VIVADO_DIR?=vivado
VIVADO_PROJ?=fpga
ifdef VIVADO_DSN_SRC
ifdef VIVADO_DSN_LIB
$(error Cannot define both VIVADO_DSN_SRC and VIVADO_DSN_LIB)
endif
VIVADO_DSN_LIB=work
VIVADO_DSN_SRC.work=$(VIVADO_DSN_SRC)
endif
VIVADO_SIM_ELF?=$(VIVADO_DSN_ELF)
nomakefiledeps?=false

# checks
$(call check_option,VIVADO_LANGUAGE,VHDL-1993 VHDL-2008 VHDL-2019 Verilog)
$(foreach l,$(VIVADO_DSN_LIB),$(call check_defined,VIVADO_DSN_SRC.$l))
$(call check_defined_alt,VIVADO_DSN_TOP VIVADO_SIM_TOP)

# local definitions
VIVADO_RUN_TCL=run.tcl
define VIVADO_RUN
	$(file >$(VIVADO_DIR)/$(VIVADO_RUN_TCL),set code [catch { $($1) } result]; puts $$result; exit $$code)
	@cd $(VIVADO_DIR) && $(VIVADO) -mode tcl -notrace -nolog -nojournal -source $(VIVADO_RUN_TCL) $(addprefix -tclargs ,$2)
endef
VIVADO_BD_SRC_DIR=$(VIVADO_PROJ).srcs/sources_1/bd
VIVADO_BD_GEN_DIR?=$(VIVADO_PROJ).gen/sources_1/bd
VIVADO_XSA=$(VIVADO_DSN_TOP).xsa
VIVADO_BIT=$(VIVADO_DSN_TOP).bit
makefiledeps=$(if $(filter true,$(nomakefiledeps)),,$(MAKEFILE_LIST))
vivado_touch_dir=$(VIVADO_DIR)/touch

# functions
VIVADO_SRC_FILE=$(foreach s,$1,$(word 1,$(subst =, ,$s)))
VIVADO_SIM_LOG=$(foreach r,$1,$(VIVADO_PROJ).sim/$r/behav/xsim/simulate.log)

# simulation
ifneq (,$(VIVADO_SIM_RUN))
ifneq (1,$(words $(VIVADO_SIM_RUN)))
$(foreach r,$(VIVADO_SIM_RUN),$(if $(findstring :,$(word 1,$(subst ;, ,$r))),,$(error Multiple simulation runs must be named)))
else
$(if $(findstring :,$(word 1,$(subst ;, ,$(VIVADO_SIM_RUN)))),,$(eval VIVADO_SIM_RUN=sim:$(value VIVADO_SIM_RUN)))
endif
VIVADO_SIM_RUN_NAME=$(foreach r,$(VIVADO_SIM_RUN),$(word 1,$(subst :, ,$r)))
# sources are neither library nor run specific
ifdef VIVADO_SIM_SRC
ifdef VIVADO_SIM_LIB
$(error Cannot define both VIVADO_SIM_SRC and VIVADO_SIM_LIB)
endif
VIVADO_SIM_LIB=work
VIVADO_SIM_SRC.work=$(VIVADO_SIM_SRC)
endif
# sources are run specific
ifneq (,$(strip $(foreach r,$(VIVADO_SIM_RUN_NAME),$(VIVADO_SIM_SRC.$r))))
ifdef VIVADO_SIM_SRC
$(error Cannot define both VIVADO_SIM_SRC and VIVADO_SIM_SRC.<run>)
endif
ifdef VIVADO_SIM_LIB
$(error Cannot define both VIVADO_SIM_SRC.<run> and VIVADO_SIM_LIB)
endif
ifneq (,$(strip $(foreach r,$(VIVADO_SIM_RUN_NAME),$(VIVADO_SIM_LIB.$r))))
$(error Cannot define both VIVADO_SIM_SRC.<run> and VIVADO_SIM_LIB.<run>)
endif
ifneq (,$(strip $(foreach r,$(VIVADO_SIM_RUN_NAME),$(foreach l,$(VIVADO_SIM_LIB.$r),$(VIVADO_SIM_SRC.$l.$r)))))
$(error Cannot define both VIVADO_SIM_SRC.<run> and VIVADO_SIM_SRC.<lib>.<run>)
endif
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(eval VIVADO_SIM_LIB.$r=work))
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(eval VIVADO_SIM_SRC.work.$r=$(VIVADO_SIM_SRC.$r)))
endif
# sources are library specific
ifdef VIVADO_SIM_LIB
ifneq (,$(strip $(foreach r,$(VIVADO_SIM_RUN_NAME),$(VIVADO_SIM_LIB.$r))))
$(error Cannot define both VIVADO_SIM_LIB and VIVADO_SIM_LIB.<run>)
endif
$(foreach l,$(VIVADO_SIM_LIB),$(if $(VIVADO_SIM_SRC.$l),,$(error VIVADO_SIM_SRC.$l is empty)))
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(eval VIVADO_SIM_LIB.$r=$(VIVADO_SIM_LIB)))
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(foreach l,$(VIVADO_SIM_LIB.$r),$(eval VIVADO_SIM_SRC.$l.$r=$(VIVADO_SIM_SRC.$l))))
endif
# libraries are run specific, sources are library and run specific
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(if $(VIVADO_SIM_LIB.$r),,$(error VIVADO_SIM_LIB.$r is empty)))
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(foreach l,$(VIVADO_SIM_LIB.$r),$(if $(VIVADO_SIM_SRC.$l.$r),,$(error VIVADO_SIM_SRC.$l.$r is empty))))
else
# simulation runs not specified
ifneq (,$(strip $(VIVADO_SIM_SRC) $(VIVADO_SIM_LIB)))
$(error VIVADO_SIM_RUN not defined)
endif
endif

# constraints
$(foreach x,$(VIVADO_XDC),$(if $(findstring =,$x),,$(error All constraints must be scoped)))
VIVADO_XDC_SYNTH=$(foreach x,$(VIVADO_XDC),$(if,$(filter SYNTH,$(subst $(comma), ,$(word 2,$(subst =, ,$x)))),$(word 1,$(subst =, ,$x))))
VIVADO_XDC_IMPL=$(foreach x,$(VIVADO_XDC),$(if,$(filter IMPL,$(subst $(comma), ,$(word 2,$(subst =, ,$x)))),$(word 1,$(subst =, ,$x))))
VIVADO_XDC_SIM=$(foreach x,$(VIVADO_XDC),$(if,$(filter SIM,$(subst $(comma), ,$(word 2,$(subst =, ,$x)))),$(word 1,$(subst =, ,$x))))

################################################################################
# TCL sequences

define vivado_tcl_xpr

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
	}
	foreach s [get_filesets] {
		if {$$s != "sources_1" && $$s != "constrs_1" && $$s != "utils_1"} {
			if {!("$$s" in {$(VIVADO_SIM_RUN_NAME)})} {
				delete_fileset $$s
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
	set target_language "$(VIVADO_LANGUAGE)"
	if {"$$target_language" != "Verilog"} {
		set target_language "VHDL"
	}
	if {[get_property target_language [current_project]] != "$(VIVADO_LANGUAGE)"} {
		set_property target_language "$$target_language" [current_project]
	}
	if {"$(VIVADO_DSN_LIB)" != ""} {
		puts "adding design sources..."
		$(foreach l,$(VIVADO_DSN_LIB),add_files -norecurse -fileset [get_filesets sources_1] {$(call VIVADO_SRC_FILE,$(VIVADO_DSN_SRC.$l))};)
	}
	if {"$(VIVADO_SIM_RUN_NAME)" != ""} {
		puts "adding simulation sources..."
		$(foreach r,$(VIVADO_SIM_RUN_NAME),$(foreach l,$(VIVADO_SIM_LIB.$r),add_files -norecurse -fileset [get_filesets $r] {$(call VIVADO_SRC_FILE,$(VIVADO_SIM_SRC.$l.$r))};))
	}
	foreach f [get_files *.vh*] {
		if {[string first "$(VIVADO_DIR)/$(VIVADO_BD_GEN_DIR)/" $$f] == -1} {
			set current_type [get_property file_type [get_files $$f]]
			set desired_type [string map {"-" " "} "$(VIVADO_LANGUAGE)"]
			if {$$desired_type == "VHDL 1993"} {
				set desired_type "VHDL"
			}
			if {"$$current_type" != "$$desired_type"} {
				set_property file_type "$$desired_type" $$f
			}
		}
	}
	proc type_sources {s l} {
		foreach file_type $$l {
			if {[string first "=" "$$file_type"] != -1} {
				set file [lindex [split "$$file_type" "="] 0]
				set type [string map {"-" " "} [lindex [split "$$file_type" "="] 1]]
				if {$$type == "VHDL 1993"} {
					set type "VHDL"
				}
				set_property file_type "$$type" [get_files -of_objects [get_filesets $$s] "$$file"]
			}
		}
	}
	puts "setting design source file types..."
	$(foreach l,$(VIVADO_DSN_LIB),type_sources sources_1 {$(call VIVADO_SRC_FILE,$(VIVADO_DSN_SRC.$l))};)
	puts "setting simulation source file types..."
	$(foreach r,$(VIVADO_SIM_RUN_NAME),$(foreach l,$(VIVADO_SIM_LIB),type_sources $r {$(call VIVADO_SRC_FILE,$(VIVADO_SIM_SRC.$l.$r))};))
	if {"$(VIVADO_DSN_TOP)" != ""} {
		puts "setting top design unit..."
		if {[get_property top [get_filesets sources_1]] != "$(VIVADO_DSN_TOP)"} {
			set_property top "$(VIVADO_DSN_TOP)" [get_filesets sources_1]
		}
	}
	if {[llength {$(VIVADO_DSN_GEN)}] > 0} {
		puts "setting top design unit generics..."
		set_property generic {$(VIVADO_DSN_GEN)} [get_filesets sources_1]
	}
	if {"$(VIVADO_SIM_RUN)" != ""} {
		puts "setting top unit and generics for simulation filesets..."
	}
	foreach r {$(VIVADO_SIM_RUN)} {
		set run [lindex [split [lindex [split "$$r" ";"] 0] ":"] 0]
		set top [lindex [split [lindex [split [lindex [split "$$r" ";"] 0] ":"] 1] "$(comma)"] 0]
		set gen [split [lindex [split "$$r" ";"] 1] "$(comma)"]
		set_property top $$top [get_filesets $$run]
		if {[llength $$gen] > 0} {
			set_property generic $$gen [get_filesets $$run]
		}
	}
	puts "enabling synthesis assertions..."
	set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]
	if {"$(VIVADO_XDC)" != ""} {
		puts "adding constraints..."
	}
	$(if $(VIVADO_XDC),add_files -norecurse -fileset [get_filesets constrs_1] {$(call VIVADO_SRC_FILE,$(VIVADO_XDC))})
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
		puts "scoping constraints..."
	}
	scope_constrs {$(VIVADO_XDC)}
	exit 0

endef

#-------------------------------------------------------------------------------

define vivado_tcl_bd

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

define vivado_tcl_bd_gen

	set f [lindex $$argv 0]
	open_project $(VIVADO_PROJ)
	generate_target all [get_files -of_objects [get_filesets sources_1] [file tail $$f]]

endef

#-------------------------------------------------------------------------------

define vivado_tcl_xsa

	open_project $(VIVADO_PROJ)
	write_hw_platform -fixed -force -file $(VIVADO_DSN_TOP).xsa

endef

#-------------------------------------------------------------------------------

define vivado_tcl_dsn_elf

	set f [lindex $$argv 0]
	open_project $(VIVADO_PROJ)
	add_files -norecurse -fileset [get_filesets sources_1] $$f
	set_property used_in_implementation 1 [get_files -of_objects [get_filesets sources_1] $$f]
	set_property used_in_simulation 0 [get_files -of_objects [get_filesets sources_1] $$f]
	set_property SCOPED_TO_REF {$(VIVADO_PROC_REF)} [get_files -of_objects [get_fileset sources_1] $$f]
	set_property SCOPED_TO_CELLS {$(VIVADO_PROC_CELL)} [get_files -of_objects [get_fileset sources_1] $$f]

endef

#-------------------------------------------------------------------------------

define vivado_tcl_sim_elf

	set run [lindex $$argv 0]
	set f   [lindex $$argv 1]
	open_project $(VIVADO_PROJ)
	add_files -norecurse -fileset [get_filesets $$run] $$f
	set_property used_in_simulation 1 [get_files -of_objects [get_filesets $$run] $$f]
	set_property SCOPED_TO_REF {$(VIVADO_PROC_REF)} [get_files -of_objects [get_fileset $$run] $$f]
	set_property SCOPED_TO_CELLS {$(VIVADO_PROC_CELL)} [get_files -of_objects [get_fileset $$run] $$f]

endef


#-------------------------------------------------------------------------------

define vivado_tcl_synth

	open_project $(VIVADO_PROJ)
	reset_run synth_1
	launch_runs synth_1
	wait_on_run synth_1
	if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {exit 1}

endef

#-------------------------------------------------------------------------------

define vivado_tcl_impl

	open_project $(VIVADO_PROJ)
	reset_run impl_1
	launch_runs impl_1 -to_step route_design
	wait_on_run impl_1
	if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {exit 1}

endef

#-------------------------------------------------------------------------------

define vivado_tcl_bit

	open_project $(VIVADO_PROJ)
	open_run impl_1
	write_bitstream -force [lindex $$argv 0]

endef

#-------------------------------------------------------------------------------

define vivado_tcl_prog

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

define vivado_tcl_sim

	set r [lindex $$argv 0]
	open_project $(VIVADO_PROJ)
	current_fileset -simset [get_filesets $$r]
	launch_simulation
	run all

endef

################################################################################
# Vivado rules and recipes

.PHONY: vivado_force xpr bd hwdef xsa synth impl bit $(VIVADO_SIM_RUN_NAME)

vivado_force:

# project directory
$(VIVADO_DIR):
	@bash -c "mkdir -p $@"

# touch directory
$(vivado_touch_dir):
	@bash -c "mkdir -p $@"

# create project file
$(vivado_touch_dir)/$(VIVADO_PROJ).xpr: $(makefiledeps) | $(VIVADO_DIR) $(vivado_touch_dir)
	$(call banner,Vivado: create project)
	@bash -c "rm -f $(VIVADO_DIR)/$(VIVADO_PROJ).xpr"
	$(call VIVADO_RUN,vivado_tcl_xpr)
	@touch $@
xpr: $(vivado_touch_dir)/$(VIVADO_PROJ).xpr

# create block diagrams
define RR_VIVADO_BD
$(vivado_touch_dir)/$(basename $(notdir $(call VIVADO_SRC_FILE,$1))).bd: $(call VIVADO_SRC_FILE,$1) $(vivado_touch_dir)/$(VIVADO_PROJ).xpr
	$$(call banner,Vivado: create block diagram)
	$$(call VIVADO_RUN,vivado_tcl_bd,$1)
	@touch $$@
bd:: $(vivado_touch_dir)/$(basename $(notdir $(call VIVADO_SRC_FILE,$1))).bd
endef
$(foreach x,$(VIVADO_BD_TCL),$(eval $(call RR_VIVADO_BD,$x)))

# generate block diagram products
define RR_VIVADO_BD_GEN
$(vivado_touch_dir)/$(basename $(notdir $(call VIVADO_SRC_FILE,$1))).gen: $(vivado_touch_dir)/$(basename $(notdir $(call VIVADO_SRC_FILE,$1))).bd
	$$(call banner,Vivado: generate block diagram products)
	$$(call VIVADO_RUN,vivado_tcl_bd_gen,$(basename $(notdir $(call VIVADO_SRC_FILE,$1))).bd)
	@touch $$@
gen:: $(vivado_touch_dir)/$(basename $(notdir $(call VIVADO_SRC_FILE,$1))).gen
endef
$(foreach x,$(VIVADO_BD_TCL),$(eval $(call RR_VIVADO_BD_GEN,$x)))

# generate hardware handoff (XSA) file
$(vivado_touch_dir)/$(VIVADO_PROJ).xsa: $(foreach x,$(VIVADO_BD_TCL),$(addprefix $(vivado_touch_dir)/,$(basename $(notdir $(call VIVADO_SRC_FILE,$x))).gen))
	$(call banner,Vivado: create hardware handoff (XSA) file)
	$(call VIVADO_RUN,vivado_tcl_xsa)
	@touch $@
xsa: $(vivado_touch_dir)/$(VIVADO_PROJ).xsa

# associate design ELF file
$(vivado_touch_dir)/dsn.elf: $(VIVADO_DSN_ELF) $(vivado_touch_dir)/$(VIVADO_PROJ).xpr
	$(call banner,Vivado: associate design ELF file)
	$(call VIVADO_RUN,vivado_tcl_dsn_elf,$(abspath $<))
	@touch $@

# associate simulation ELF files
define rr_simelf
$(vivado_touch_dir)/sim_$1.elf: $(VIVADO_SIM_ELF) $(vivado_touch_dir)/$(VIVADO_PROJ).xpr
	$$(call banner,Vivado: associate simulation ELF file (run: $1))
	$$(call VIVADO_RUN,vivado_tcl_sim_elf,$1 $$(abspath $$<))
	@touch $$@
endef
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(eval $(call rr_simelf,$r)))

# synthesis
$(vivado_touch_dir)/$(VIVADO_PROJ).synth: $(call VIVADO_SRC_FILE,$(foreach l,$(VIVADO_DSN_LIB),$(VIVADO_DSN_SRC.$l))) $(call VIVADO_SRC_FILE,$(VIVADO_XDC_SYNTH)) $(foreach x,$(VIVADO_BD_TCL),$(addprefix $(vivado_touch_dir)/,$(basename $(notdir $(call VIVADO_SRC_FILE,$x))).gen)) $(vivado_touch_dir)/$(VIVADO_PROJ).xpr
	$(call banner,Vivado: synthesis)
	$(call VIVADO_RUN,vivado_tcl_synth)
	@touch $@
synth: $(vivado_touch_dir)/$(VIVADO_PROJ).synth

# implementation (place and route) and preparation for simulation
$(vivado_touch_dir)/$(VIVADO_PROJ).impl: $(vivado_touch_dir)/$(VIVADO_PROJ).synth $(call VIVADO_SRC_FILE,$(VIVADO_XDC_IMPL)) $(if $(VITIS_APP),$(vivado_touch_dir)/dsn.elf)
	$(call banner,Vivado: implementation)
	$(call VIVADO_RUN,vivado_tcl_impl)
	@touch $@
impl: $(vivado_touch_dir)/$(VIVADO_PROJ).impl

# write bitstream
$(vivado_touch_dir)/$(VIVADO_PROJ).bit: $(vivado_touch_dir)/$(VIVADO_PROJ).impl
	$(call banner,Vivado: write bitstream)
	$(call VIVADO_RUN,vivado_tcl_bit,$(abspath $(VIVADO_BIT)))
	@touch $@
bit: $(vivado_touch_dir)/$(VIVADO_PROJ).bit

# program
prog: vivado_force $(vivado_touch_dir)/$(VIVADO_PROJ).bit
	$(call banner,Vivado: program)
	$(call VIVADO_RUN,vivado_tcl_prog,$(abspath $(VIVADO_BIT)))

# simulation preparation
simprep: $(vivado_touch_dir)/$(VIVADO_PROJ).xpr $(if $(VITIS_APP),$(foreach r,$(VIVADO_SIM_RUN_NAME),$(vivado_touch_dir)/sim_$r.elf))
	$(call banner,Vivado: simulation preparation)

# simulation runs
define rr_simrun
$1: vivado_force $(vivado_touch_dir)/$(VIVADO_PROJ).xpr $(if $(VITIS_APP),$(vivado_touch_dir)/sim_$1.elf)
	$$(call banner,Vivado: simulation run = $1)
	$$(call VIVADO_RUN,vivado_tcl_sim,$1)
endef
$(foreach r,$(VIVADO_SIM_RUN_NAME),$(eval $(call rr_simrun,$r)))

################################################################################
# Visual Studio Code

VSCODE_DIR=$(VIVADO_DIR)/vscode
VSCODE_TOP=$(VIVADO_DSN_TOP) $(foreach r,$(VIVADO_SIM_RUN),$(word 2,$(subst ;, ,$(subst :, ,,$r))))
VSCODE_LIB=$(call uniq,$(VIVADO_DSN_LIB) $(VIVADO_XLIB) $(VIVADO_SIM_LIB))
$(foreach l,$(VIVADO_DSN_LIB),$(eval VSCODE_SRC.$l+=$(call VIVADO_SRC_FILE,$(VIVADO_DSN_SRC.$l))))
$(foreach l,$(VIVADO_XLIB),$(eval VSCODE_SRC.$l+=$(call VIVADO_SRC_FILE,$(VIVADO_XSRC.$l))))
$(foreach l,$(VIVADO_SIM_LIB),$(eval VSCODE_SRC.$l+=$(call VIVADO_SRC_FILE,$(VIVADO_SIM_SRC.$l))))
VSCODE_AUX=\
	$(call VIVADO_SRC_FILE,$(VIVADO_BD_TCL)) \
	$(call VIVADO_SRC_FILE,$(VIVADO_XDC))

# workspace directory
$(VSCODE_DIR):
	@bash -c "mkdir -p $@"

# library directory(s) containing symbolic link(s) to source(s)
$(foreach l,$(VSCODE_LIB),$(eval $l: $(addprefix $$(VSCODE_DIR)/$l/,$(notdir $(VSCODE_SRC.$l)))))

# symbolic links to source files
ifeq ($(OS),Windows_NT)
define rr_srclink
$$(VSCODE_DIR)/$1/$(notdir $2): $2
	@bash -c "mkdir -p $$(dir $$@) && rm -f $$@"
	@bash -c "cmd.exe //C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
endef
else
define rr_srclink
$$(VSCODE_DIR)/$1/$(notdir $2): $2
	@mkdir -p $$(dir $$@)
	@ln $$< $$@
endef
endif
$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),$(eval $(call rr_srclink,$l,$s))))

# symbolic links to auxilliary text files
ifeq ($(OS),Windows_NT)
define rr_auxlink
$$(VSCODE_DIR)/$(notdir $1): $1
	@bash -c "rm -f $$@"
	@bash -c "cmd.exe //C \"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\""
endef
else
define rr_auxlink
$$(VSCODE_DIR)/$(notdir $1): $1
	@ln $$< $$@
endef
endif
$(foreach a,$(VSCODE_AUX),$(eval $(call rr_auxlink,$a)))

# V4P configuration file
$(VSCODE_DIR)/config.v4p: vivado_force $(VSCODE_LIB)
	@bash -c "echo \"[libraries]\" > $@"
	@bash -c "$(foreach l,$(VSCODE_LIB),$(foreach s,$(VSCODE_SRC.$l),echo \"$l/$(notdir $s)=$l\" >> $@;))"
	@bash -c "echo \"[settings]\" >> $@"
	@bash -c "echo \"V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(VSCODE_TOP))\" >> $@"

edit:: $(VSCODE_DIR)/config.v4p $(addprefix $(VSCODE_DIR)/,$(VSCODE_LIB)) $(addprefix $(VSCODE_DIR)/,$(notdir $(VSCODE_AUX)))
	@cd $(VSCODE_DIR) && code .

################################################################################

clean::
	@rm -rf $(VIVADO_DIR)
