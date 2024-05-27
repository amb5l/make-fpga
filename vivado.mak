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

# checks
$(call check_defined,VIVADO_PART)
$(call check_option,VIVADO_LANGUAGE,VHDL-1993 VHDL-2008 VHDL-2019 Verilog)
$(foreach l,$(VIVADO_DSN_LIB),$(call check_defined,VIVADO_DSN_SRC.$l))
$(foreach l,$(VIVADO_SIM_LIB),$(call check_defined,VIVADO_SIM_SRC.$l))
$(call check_defined_alt,VIVADO_DSN_TOP VIVADO_SIM_TOP)

# local definitions
VIVADO_RUN_TCL=run.tcl
VIVADO_RUN=\
	@cd $(VIVADO_DIR) && \
	printf "set code [catch {\n$1\n} result]\nputs \$$result\nexit \$$code\n" > $(VIVADO_RUN_TCL) && \
	$(VIVADO) -mode tcl -notrace -nolog -nojournal -source $(VIVADO_RUN_TCL)
VIVADO_XPR?=$(VIVADO_PROJ).xpr
VIVADO_XDC_FILES=$(foreach x,$(VIVADO_XDC),$(word 1,$(subst =, ,$x)))
VIVADO_SYNTH_DCP=$(VIVADO_PROJ).runs/synth_1/$(VIVADO_DSN_TOP).dcp
VIVADO_IMPL_DCP=$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP)_routed.dcp
VIVADO_BIT=$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP).bit

# functions
VIVADO_SRC_FILE=$(foreach s,$1,$(word 1,$(subst =, ,$s)))

# simulation
ifdef VIVADO_SIM_RUN
ifneq (1,$(words,$(strip $(VIVADO_SIM_RUN))))
$(foreach r,$(VIVADO_SIM_RUN),$(if $(findstring :,$(word 1,$(subst ;, ,$r))),,$(error Multiple simulation runs must be named)))
else
$(if $(findstring :,$(word 1,$(subst ;, ,$(VIVADO_SIM_RUN))),,$(eval VIVADO_SIM_RUN=sim:$(value VIVADO_SIM_RUN)))
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

################################################################################
# rules and recipes

# project directory
$(VIVADO_DIR):
	@bash -c "mkdir -p $@"

# project file
$(VIVADO_DIR)/$(VIVADO_XPR): force | $(VIVADO_DIR)
	$(call banner,Vivado: create/update project)
	$(call VIVADO_RUN, \
		if {[file exists $(VIVADO_XPR)]} { \n \
			open_project \"$(basename $(VIVADO_XPR))\" \n \
		} else { \n \
			create_project $(if $(VIVADO_PART),-part \"$(VIVADO_PART)\") -force \"$(VIVADO_PROJ)\" \n \
		} \n \
		if {\"$(VIVADO_SIM_RUN)\" != \"\"} { \n \
			foreach r {$(VIVADO_SIM_RUN)} { \n \
				set run [lindex [split \"\$$r\" \":\"] 0] \n \
				if {!(\"\$$run\" in [get_filesets])} { \n \
					create_fileset -simset \$$run \n \
				} \n \
				set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets \$$run] \n \
			} \n \
			current_fileset -simset [get_filesets $(word 1,$(VIVADO_SIM_RUNS))] \n \
		} \n \
		if {!(\"sim_1\" in {$(VIVADO_SIM_RUNS)})} { \n \
			delete_fileset sim_1 \n \
		} \n \
		if {[get_property part [current_project]] != \"$(VIVADO_PART)\"} { \n \
			set_property part \"$(VIVADO_PART)\" [current_project] \n \
		} \n \
		set target_language \"$(VIVADO_LANGUAGE)\" \n \
		if {\$$target_language != \"Verilog\"} { \n \
			set target_language \"VHDL\" \n \
		} \n \
		if {[get_property target_language [current_project]] != \"$(VIVADO_LANGUAGE)\"} { \n \
			set_property target_language \"\$$target_language\" [current_project] \n \
		} \n \
		proc update_files {target_fileset new_files} { \n \
			proc diff_files {a b} { \n \
				set r [list] \n \
				foreach f \$$a { \n \
					if {!("\$$f" in "\$$b")} { \n \
						lappend r \$$f \n \
					} \n \
				} \n \
				return \$$r \n \
			} \n \
			set current_files [get_files -quiet -of_objects [get_fileset \$$target_fileset] *.*] \n \
			if {[llength \$$current_files]} { \n \
				set missing_files [diff_files {\$$new_files} {\$$current_files}] \n \
				if {[llength \$$missing_files]} { \n \
					add_files -norecurse -fileset [get_filesets \$$target_fileset] \$$missing_files \n \
				} \n \
				set surplus_files [diff_files {\$$current_files} {\$$new_files}] \n \
				if {[llength \$$surplus_files]} { \n \
					remove_files -fileset \$$target_fileset \$$surplus_files \n \
				} \n \
			} else { \n \
				add_files -norecurse -fileset [get_filesets \$$target_fileset] \$$new_files \n \
			} \n \
		} \n \
		$(foreach l,$(VIVADO_DSN_LIB),update_files sources_1 {$(call VIVADO_SRC_FILE,VIVADO_DSN_SRC.$l)} \n) \
		$(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB.$r),update_files $r {$(call VIVADO_SRC_FILE,$(VIVADO_SIM_SRC.$l.$r))} \n)) \
		foreach f [get_files *.vh*] { \n \
			set current_type [get_property file_type [get_files \$$f]] \n \
			set desired_type [string map {\"-\" \" \"} \"$(VIVADO_LANGUAGE)\"] \n \
			if {\$$desired_type == \"VHDL 1993\"} { \n \
				set desired_type \"VHDL\" \n \
			} \n \
			if {\"\$$current_type\" != \"\$$desired_type\"} { \n \
				set_property file_type \"\$$desired_type\" \$$f \n \
			} \n \
		} \n \
		proc type_sources {s l} { \n \
			foreach file_type \$$l { \n \
				if {[string first \"=\" \"\$$file_type\"] != -1} { \n \
					set file [lindex [split \"\$$file_type\" \"=\"] 0] \n \
					set type [string map {\"-\" \" \"} [lindex [split \"\$$file_type\" \"=\"] 1]] \n \
					if {\$$type == \"VHDL 1993\"} { \n \
						set type \"VHDL\" \n \
					} \n \
					set_property file_type \"\$$type\" [get_files -of_objects [get_filesets \$$s] \"\$$file\"] \n \
				} \n \
			} \n \
		} \n \
		$(foreach l,$(VIVADO_DSN_LIB),type_sources sources_1 $(VIVADO_DSN_SRC.$l)} \n) \
		$(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB),type_sources $r {$(VIVADO_SIM_SRC.$l.$r)} \n)) \
		if {\"$(VIVADO_DSN_TOP)\" != \"\"} { \n \
			if {[get_property top [get_filesets sources_1]] != \"$(VIVADO_DSN_TOP)\"} { \n \
				set_property top \"$(VIVADO_DSN_TOP)\" [get_filesets sources_1] \n \
			} \n \
		} \n \
		$(foreach r,$(VIVADO_SIM_RUN), \
			set run $(word 1,$(subst :, ,$(word 1,$(subst ;, ,$r)))) \n \
			set top $(word 2,$(subst :, ,$(word 1,$(subst ;, ,$r)))) \n \
			set gen [split [lindex [split \"\$$r\" \";\"] 1] \"$(comma)\"] \n \
			if {[get_property top [get_filesets \$$run]] != \"\$$top\"} { \n \
				set_property top \$$top [get_filesets \$$run] \n \
			} \n \
			set_property generic \$$gen [get_filesets \$$run] \n \
		) \
		if {[get_property STEPS.SYNTH_DESIGN.ARGS.ASSERT [get_runs synth_1]]} { \n \
			set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1] \n \
		} \n \
		$(if $(VIVADO_XDC_FILES),update_files constrs_1 {$(VIVADO_XDC_FILES)} \n) \
		proc scope_constrs {xdc} { \n \
			foreach x \$$xdc { \n \
				set file  [lindex [split \"\$$x\" \"=\"] 0] \n \
				set scope [lindex [split \"\$$x\" \"=\"] 1] \n \
				set_property used_in_synthesis      [expr [string first \"SYNTH\" \"\$$scope\"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] \$$file] \n \
				set_property used_in_implementation [expr [string first \"IMPL\"  \"\$$scope\"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] \$$file] \n \
				set_property used_in_simulation     [expr [string first \"SIM\"   \"\$$scope\"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] \$$file] \n \
			} \n \
		} \n \
		scope_constrs {$(VIVADO_XDC)} \n \
		exit 0 \
	)

# synthesis
$(VIVADO_DIR)/$(VIVADO_SYNTH_DCP): $(foreach l,$(VIVADO_DSN_LIB),$(VIVADO_DSN_SRC.$l)) $(VIVADO_DSN_XDC_SYNTH) $(VIVADO_DSN_XDC) | $(VIVADO_DIR)/$(VIVADO_XPR)
	$(call banner,Vivado: synthesis)
	$(call VIVADO_RUN, \
		open_project $(VIVADO_PROJ)
		reset_run synth_1 \n \
		launch_runs synth_1 -jobs $jobs \n \
		wait_on_run synth_1 \n \
		if {[get_property PROGRESS [get_runs synth_1]] != \"100%\"} {exit 1} \n \
		exit 0 \
	)

# implementation (place and route) and preparation for simulation
# NOTE: implementation changes BD timestamp which upsets dependancies,
#  so we force BD modification time backwards
$(VIVADO_DIR)/$(VIVADO_IMPL_DCP): $(VIVADO_DIR)/$(VIVADO_SYNTH_DCP) $(VIVADO_DSN_XDC_IMPL) $(VIVADO_DSN_ELF) $(VIVADO_SIM_ELF)
	$(call banner,Vivado: implementation)
	$(call VIVADO_RUN, \
		reset_run impl_1 \n \
		launch_runs impl_1 -to_step route_design \n \
		wait_on_run impl_1 \n \
		if {[get_property PROGRESS [get_runs impl_1]] != \"100%\"} {exit 1} \n \
		exit 0 \
	)

# write bitstream
$(VIVADO_DIR)/$(VIVADO_BIT): $(VIVADO_DIR)/$(VIVADO_IMPL_DCP)
	$(call banner,Vivado: write bitstream)
	$(call VIVADO_RUN, \
		reset_run impl_1 \n \
		launch_runs impl_1 -to_step write_bitstream \n \
		wait_on_run impl_1 \n \
		if {[get_property PROGRESS [get_runs impl_1]] != \"100%\"} {exit 1} \n \
		exit 0 \
	)

################################################################################
# goals

.PHONY: xpr synth impl bit

xpr   : $(VIVADO_DIR)/$(VIVADO_XPR)

synth : $(VIVADO_DIR)/$(VIVADO_SYNTH_DCP)

impl  : $(VIVADO_DIR)/$(VIVADO_IMPL_DCP)

bit   : $(VIVADO_DIR)/$(VIVADO_BIT)
	@mv $(VIVADO_DIR)/$(VIVADO_BIT) .

clean::
	@rm -rf $(VIVADO_DIR)
