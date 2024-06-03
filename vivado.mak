################################################################################
# vivado.mak
# See https://github.com/amb5l/make-fpga
################################################################################
# TODO:
#	execute simulation runs
#	design generics
#	ELF/CPU support
#	timing simulation

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
VIVADO_XPR?=$(VIVADO_PROJ).xpr
VIVADO_DSN_BD_SRC_DIR=$(VIVADO_PROJ).srcs/sources_1/bd
VIVADO_DSN_BD_GEN_DIR?=$(VIVADO_PROJ).gen/sources_1/bd
VIVADO_DSN_BD=$(foreach x,$(VIVADO_DSN_BD_TCL),$(VIVADO_DSN_BD_SRC_DIR)/$(basename $(notdir $x))/$(basename $(notdir $x)).bd)
VIVADO_DSN_BD_HWDEF=$(foreach x,$(VIVADO_DSN_BD),$(VIVADO_DSN_BD_GEN_DIR)/$(basename $(notdir $x))/synth/$(basename $(notdir $x)).hwdef)
VIVADO_XSA=$(VIVADO_DSN_TOP).xsa
VIVADO_SYNTH_DCP=$(VIVADO_PROJ).runs/synth_1/$(VIVADO_DSN_TOP).dcp
VIVADO_IMPL_DCP=$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP)_routed.dcp
VIVADO_BIT=$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP).bit
makefiledeps=$(if $(filter true,$(nomakefiledeps)),,$(MAKEFILE_LIST))

# functions
VIVADO_SRC_FILE=$(foreach s,$1,$(word 1,$(subst =, ,$s)))
VIVADO_SIM_LOG=$(foreach r,$1,$(VIVADO_PROJ).sim/$(word 1,$(subst $(comma),$(space),$r))/behav/xsim/simulate.log)

# simulation
ifdef VIVADO_SIM_RUN
ifneq (1,$(words $(VIVADO_SIM_RUN)))
$(foreach r,$(VIVADO_SIM_RUN),$(if $(findstring :,$(word 1,$(subst ;, ,$r))),,$(error Multiple simulation runs must be named)))
else
$(if $(findstring :,$(word 1,$(subst ;, ,$(VIVADO_SIM_RUN)))),,$(eval VIVADO_SIM_RUN=sim:$(value VIVADO_SIM_RUN)))
endif
endif
VIVADO_SIM_RUNS=$(foreach r,$(VIVADO_SIM_RUN),$(word 1,$(subst :, ,$(word 1,$(subst ;, ,$r)))))
# sources are neither library nor run specific
ifdef VIVADO_SIM_SRC
ifdef VIVADO_SIM_LIB
$(error Cannot define both VIVADO_SIM_SRC and VIVADO_SIM_LIB)
endif
VIVADO_SIM_LIB=work
VIVADO_SIM_SRC.work=$(VIVADO_SIM_SRC)
endif
# sources are run specific
ifneq (,$(strip $(foreach r,$(VIVADO_SIM_RUNS),$(VIVADO_SIM_SRC.$r))))
ifdef VIVADO_SIM_SRC
$(error Cannot define both VIVADO_SIM_SRC and VIVADO_SIM_SRC.<run>)
endif
ifdef VIVADO_SIM_LIB
$(error Cannot define both VIVADO_SIM_SRC.<run> and VIVADO_SIM_LIB)
endif
ifneq (,$(strip $(foreach r,$(VIVADO_SIM_RUNS),$(VIVADO_SIM_LIB.$r))))
$(error Cannot define both VIVADO_SIM_SRC.<run> and VIVADO_SIM_LIB.<run>)
endif
ifneq (,$(strip $(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB.$r),$(VIVADO_SIM_SRC.$l.$r)))))
$(error Cannot define both VIVADO_SIM_SRC.<run> and VIVADO_SIM_SRC.<lib>.<run>)
endif
$(foreach r,$(VIVADO_SIM_RUNS),$(eval VIVADO_SIM_LIB.$r=work))
$(foreach r,$(VIVADO_SIM_RUNS),$(eval VIVADO_SIM_SRC.work.$r=$(VIVADO_SIM_SRC.$r)))
endif
# sources are library specific
ifdef VIVADO_SIM_LIB
ifneq (,$(strip $(foreach r,$(VIVADO_SIM_RUNS),$(VIVADO_SIM_LIB.$r))))
$(error Cannot define both VIVADO_SIM_LIB and VIVADO_SIM_LIB.<run>)
endif
$(foreach l,$(VIVADO_SIM_LIB),$(if $(VIVADO_SIM_SRC.$l),,$(error VIVADO_SIM_SRC.$l is empty)))
$(foreach r,$(VIVADO_SIM_RUNS),$(eval VIVADO_SIM_LIB.$r=$(VIVADO_SIM_LIB)))
$(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB.$r),$(eval VIVADO_SIM_SRC.$l.$r=$(VIVADO_SIM_SRC.$l))))
endif
# libraries are run specific, sources are library and run specific
$(foreach r,$(VIVADO_SIM_RUNS),$(if $(VIVADO_SIM_LIB.$r),,$(error VIVADO_SIM_LIB.$r is empty)))
$(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB.$r),$(if $(VIVADO_SIM_SRC.$l.$r),,$(error VIVADO_SIM_SRC.$l.$r is empty))))

# constraints
$(foreach x,$(VIVADO_XDC),$(if $(findstring =,$x),,$(error All constraints must be scoped)))
VIVADO_XDC_SYNTH=$(foreach x,$(VIVADO_XDC),$(if,$(filter SYNTH,$(subst $(comma), ,$(word 2,$(subst =, ,$x)))),$(word 1,$(subst =, ,$x))))
VIVADO_XDC_IMPL=$(foreach x,$(VIVADO_XDC),$(if,$(filter IMPL,$(subst $(comma), ,$(word 2,$(subst =, ,$x)))),$(word 1,$(subst =, ,$x))))
VIVADO_XDC_SIM=$(foreach x,$(VIVADO_XDC),$(if,$(filter SIM,$(subst $(comma), ,$(word 2,$(subst =, ,$x)))),$(word 1,$(subst =, ,$x))))

################################################################################
# TCL sequences

define vivado_tcl_xpr

	create_project $(if $(VIVADO_PART),-part "$(VIVADO_PART)") -force "$(VIVADO_PROJ)"
	if {"$(VIVADO_SIM_RUN)" != ""} {
		puts "adding/updating simulation filesets..."
		foreach r {$(VIVADO_SIM_RUN)} {
			set run [lindex [split "$$r" ":"] 0]
			if {!("$$run" in [get_filesets])} {
				create_fileset -simset $$run
			}
			set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets $$run]
		}
		current_fileset -simset [get_filesets $(word 1,$(VIVADO_SIM_RUNS))]
	}
	foreach s [get_filesets] {
		if {!("$s" in {$(VIVADO_SIM_RUNS)})} {
			delete_fileset $s
			}
		}
	}
	puts "checking/setting part..."
	if {"$(VIVADO_PART)" != ""} {
		if {[get_property part [current_project]] != "$(VIVADO_PART)"} {
			set_property part "$(VIVADO_PART)" [current_project]
		}
	}
	puts "checking/setting target language..."
	set target_language "$(VIVADO_LANGUAGE)"
	if {"$$target_language" != "Verilog"} {
		set target_language "VHDL"
	}
	puts "target_language=$$target_language"
	if {[get_property target_language [current_project]] != "$(VIVADO_LANGUAGE)"} {
		set_property target_language "$$target_language" [current_project]
	}
	proc update_files {target_fileset new_files} {
		proc diff_files {a b} {
			set r [list]
			foreach f $$a {
				if {!("$$f" in "$$b")} {
					lappend r $$f
				}
			}
			return $$r
		}
		set current_files [get_files -quiet -of_objects [get_fileset $$target_fileset] *.*]
		if {[llength $$current_files]} {
			set missing_files [diff_files $$new_files $$current_files]
			if {[llength $$missing_files]} {
				add_files -norecurse -fileset [get_filesets $$target_fileset] $$missing_files
			}
			set l [diff_files $$current_files $$new_files]
			set surplus_files [list]
			set exclude {.bd .xci}
			foreach f $$l {
				if {!([file extension $$f] in $$exclude) && !([string first "$(VIVADO_DIR)/$(VIVADO_DSN_BD_GEN_DIR)/" $$f] != -1)} {
					lappend surplus_files $$f
				}
			}
			if {[llength $$surplus_files]} {
				remove_files -fileset $$target_fileset $$surplus_files
			}
		} else {
			add_files -norecurse -fileset [get_filesets $$target_fileset] $$new_files
		}
	}
	puts "adding/updating design sources..."
	$(foreach l,$(VIVADO_DSN_LIB),update_files sources_1 {$(call VIVADO_SRC_FILE,$(VIVADO_DSN_SRC.$l))};)
	puts "adding/updating simulation sources..."
	$(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB.$r),update_files $r {$(call VIVADO_SRC_FILE,$(VIVADO_SIM_SRC.$l.$r))};))
	foreach f [get_files *.vh*] {
		if {[string first "$(VIVADO_DIR)/$(VIVADO_PROJ).gen/sources_1/bd/" $$f] == -1} {
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
	puts "checking/setting design source file types..."
	$(foreach l,$(VIVADO_DSN_LIB),type_sources sources_1 {$(call VIVADO_SRC_FILE,$(VIVADO_DSN_SRC.$l))};)
	puts "checking/setting simulation source file types..."
	$(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB),type_sources $r {$(call VIVADO_SRC_FILE,$(VIVADO_SIM_SRC.$l.$r))};))
	puts "checking/setting top design unit..."
	if {"$(VIVADO_DSN_TOP)" != ""} {
		if {[get_property top [get_filesets sources_1]] != "$(VIVADO_DSN_TOP)"} {
			set_property top "$(VIVADO_DSN_TOP)" [get_filesets sources_1]
		}
	}
	if {"$(VIVADO_SIM_RUN)" != ""} {
		puts "checking/setting top unit and generics for simulation filesets..."
	}
	foreach r {$(VIVADO_SIM_RUN)} {
		set run [lindex [split [lindex [split "$$r" ";"] 0] ":"] 0]
		set top [lindex [split [lindex [split [lindex [split "$$r" ";"] 0] ":"] 1] "$(comma)"] 0]
		set gen [split [lindex [split "$$r" ";"] 1] "$(comma)"]
		set_property top $$top [get_filesets $$run]
		set_property generic $$gen [get_filesets $$run]
	}
	puts "checking/enabling synthesis assertions..."
	set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]
	if {"$(VIVADO_XDC)" != ""} {
		puts "adding/updating constraints..."
	}
	$(if $(VIVADO_XDC),update_files constrs_1 {$(call VIVADO_SRC_FILE,$(VIVADO_XDC))})
	proc scope_constrs {xdc} {
		foreach x $$xdc {
			set file  [lindex [split "$$x" "="] 0]
			set scope [lindex [split "$$x" "="] 1]
			set_property used_in_synthesis      [expr [string first "SYNTH" "$$scope"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] $$file]
			set_property used_in_implementation [expr [string first "IMPL"  "$$scope"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] $$file]
			set_property used_in_simulation     [expr [string first "SIM"   "$$scope"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] $$file]
		}
	}
	if {"$(VIVADO_XDC)" != ""} {
		puts "checking/scoping constraints..."
	}
	scope_constrs {$(VIVADO_XDC)}
	exit 0

endef

#-------------------------------------------------------------------------------

define vivado_tcl_bd

	set f [lindex $$argv 0]
	set design [file rootname [file tail $$f]]
	open_project $(VIVADO_PROJ)
	if {[get_files -quiet -of_objects [get_filesets sources_1] "$$design.bd"] != ""} {
		export_ip_user_files -of_objects [get_files -of_objects [get_filesets sources_1] "$$design.bd"] -no_script -reset -force -quiet
		remove_files [get_files -of_objects [get_filesets sources_1] "$$design.bd"]
		file delete -force $(VIVADO_DSN_BD_SRC_DIR)/$$design
		file delete -force $(VIVADO_DSN_BD_GEN_DIR)/$$design
	}
	source $$f

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
	reset_run impl_1
	launch_runs impl_1 -to_step write_bitstream
	wait_on_run impl_1
	if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {exit 1}

endef

#-------------------------------------------------------------------------------

define vivado_tcl_sim_run

	open_project $$(VIVADO_PROJ)
	current_fileset -simset [get_filesets $1]
	launch_simulation
	run all

endef

################################################################################
# rules and recipes

# project directory
$(VIVADO_DIR):
	@bash -c "mkdir -p $@"

# project file
$(VIVADO_DIR)/$(VIVADO_XPR): $(makefiledeps) | $(VIVADO_DIR)
	$(call banner,Vivado: create project)
	@bash -c "rm -f $@"
	$(call VIVADO_RUN,vivado_tcl_xpr)

# block diagrams
define RR_VIVADO_BD
$(VIVADO_DIR)/$(VIVADO_DSN_BD_SRC_DIR)/$(basename $(notdir $1))/$(basename $(notdir $1)).bd: $1 $(VIVADO_DIR)/$(VIVADO_XPR)
	$$(call banner,Vivado: create block diagrams)
	$$(call VIVADO_RUN,vivado_tcl_bd,$$<)
endef
$(foreach x,$(VIVADO_DSN_BD_TCL),$(eval $(call RR_VIVADO_BD,$x)))

# block diagram hardware definitions
define RR_VIVADO_BD_GEN
$(VIVADO_DIR)/$(VIVADO_DSN_BD_GEN_DIR)/$(basename $(notdir $1))/synth/$(basename $(notdir $1)).hwdef: $(VIVADO_DIR)/$1
	$$(call banner,Vivado: generate block diagram hardware definitions)
	$$(call VIVADO_RUN,vivado_tcl_bd_gen,$$<)
	@touch $$<
	@touch $$@
endef
$(foreach x,$(VIVADO_DSN_BD),$(eval $(call RR_VIVADO_BD_GEN,$x)))

# hardware handoff (XSA) file
$(VIVADO_DIR)/$(VIVADO_XSA): $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD_HWDEF))
	$(call banner,Vivado: create hardware handoff (XSA) file)
	$(call VIVADO_RUN,vivado_tcl_xsa)
	@touch $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD))
	@touch $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD_HWDEF))
	@touch $@

# synthesis
$(VIVADO_DIR)/$(VIVADO_SYNTH_DCP): $(foreach l,$(VIVADO_DSN_LIB),$(VIVADO_DSN_SRC.$l)) $(VIVADO_XDC_SYNTH) $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD_HWDEF) $(VIVADO_XPR))
	$(call banner,Vivado: synthesis)
	$(call VIVADO_RUN,vivado_tcl_synth)
	@touch $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD))
	@touch $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD_HWDEF))
	@touch $(VIVADO_DIR)/$(VIVADO_XSA)
	@touch $@

# implementation (place and route) and preparation for simulation
# TODO: implementation changes BD timestamp which upsets dependancies, so force BD modification time backwards
$(VIVADO_DIR)/$(VIVADO_IMPL_DCP): $(VIVADO_DIR)/$(VIVADO_SYNTH_DCP) $(VIVADO_XDC_IMPL) $(VIVADO_DSN_ELF) $(VIVADO_SIM_ELF)
	$(call banner,Vivado: implementation)
	$(call VIVADO_RUN,vivado_tcl_impl)
	@touch $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD))
	@touch $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD_HWDEF))
	@touch $(VIVADO_DIR)/$(VIVADO_XSA)
	$(addprefix @touch -c ,$(VITIS_DIR)/$(VITIS_PRJ))
	$(addprefix @touch -c ,$(VIVADO_DSN_ELF))
	$(addprefix @touch -c ,$(VIVADO_SIM_ELF))
	@touch $(VIVADO_DIR)/$(VIVADO_SYNTH_DCP)
	@touch $@

# write bitstream
$(VIVADO_DIR)/$(VIVADO_BIT): $(VIVADO_DIR)/$(VIVADO_IMPL_DCP)
	$(call banner,Vivado: write bitstream)
	$(call VIVADO_RUN,vivado_tcl_bit)
	@touch $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD))
	@touch $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD_HWDEF))
	@touch $(VIVADO_DIR)/$(VIVADO_XSA)
	$(addprefix @touch -c ,$(VITIS_DIR)/$(VITIS_PRJ))
	$(addprefix @touch -c ,$(VIVADO_DSN_ELF))
	$(addprefix @touch -c ,$(VIVADO_SIM_ELF))
	@touch $(VIVADO_DIR)/$(VIVADO_SYNTH_DCP)
	@touch $(VIVADO_DIR)/$(VIVADO_IMPL_DCP)
	@touch $@

# simulation runs
define rr_simrun
$(call VIVADO_SIM_LOG,$1): vivado_force $(VIVADO_DIR)/$(VIVADO_XPR)
	$$(call banner,Vivado: simulation run = $1)
	$$(call VIVADO_RUN,vivado_tcl_sim_run)
endef
$(foreach r,$(VIVADO_SIM_RUNS),$(eval $(call rr_simrun,$r)))

################################################################################
# goals

.PHONY: vivado_force xpr bd hwdef xsa synth impl bit $(VIVADO_SIM_RUNS)

vivado_force:

xpr   : $(VIVADO_DIR)/$(VIVADO_XPR)

bd    : $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD))

hwdef : $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD_HWDEF))

xsa   : $(VIVADO_DIR)/$(VIVADO_XSA)

synth : $(VIVADO_DIR)/$(VIVADO_SYNTH_DCP)

impl  : $(VIVADO_DIR)/$(VIVADO_IMPL_DCP)

bit   : $(VIVADO_DIR)/$(VIVADO_BIT)
	@mv $(VIVADO_DIR)/$(VIVADO_BIT) .

$(foreach r,$(VIVADO_SIM_RUNS),$(eval \
$r    : $(addprefix $(VIVADO_DIR)/,$(call VIVADO_SIM_LOG,$r)) \
))

clean::
	@rm -rf $(VIVADO_DIR)
