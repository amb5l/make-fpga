################################################################################
# vivado.mak
# See https://github.com/amb5l/make-fpga
################################################################################

# XILINX_VIVADO must contain the path to the Vivado installation
$(call check_defined,XILINX_VIVADO)
XILINX_VIVADO:=$(call xpath,$(XILINX_VIVADO))

# defaults
VIVADO?=vivado
VIVADO_DIR?=vivado
VIVADO_PROJ?=fpga
VIVADO_VHDL_LRM?=2002
VIVADO_DSN_LIB?=work

# checks
$(call check_defined,VIVADO_PART)
$(call check_option,VIVADO_LANGUAGE,VHDL Verilog)
$(call check_option,VIVADO_VHDL_LRM,2002 2008 2019)
$(foreach l,$(VIVADO_DSN_LIB),$(call check_defined,VIVADO_DSN_SRC.$l))
$(foreach l,$(VIVADO_SIM_LIB),$(call check_defined,VIVADO_SIM_SRC.$l))
$(call check_defined,VIVADO_DSN_TOP)

# local definitions
VIVADO_RUN_TCL=run.tcl
VIVADO_RUN=\
	@cd $(VIVADO_DIR) && \
	printf "set code [catch {\n$1\n} result]\nputs \$$result\nexit \$$code\n" > $(VIVADO_RUN_TCL) && \
	$(VIVADO) -mode tcl -notrace -nolog -nojournal -source $(VIVADO_RUN_TCL)
VIVADO_XPR?=$(VIVADO_PROJ).xpr
$(foreach l,$(VIVADO_DSN_LIB),$(eval VIVADO_DSN_SRC_FILES.$l=$(foreach s,$(VIVADO_DSN_SRC.$l),$(word 1,$(subst =, ,$s)))))
$(foreach l,$(VIVADO_SIM_LIB),$(eval VIVADO_SIM_SRC_FILES.$l=$(foreach s,$(VIVADO_SIM_SRC.$l),$(word 1,$(subst =, ,$s)))))
VIVADO_XDC_FILES=$(foreach x,$(VIVADO_XDC),$(word 1,$(subst =, ,$x)))
VIVADO_SYNTH_DCP=$(VIVADO_PROJ).runs/synth_1/$(VIVADO_DSN_TOP).dcp
VIVADO_IMPL_DCP=$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP)_routed.dcp
VIVADO_BIT=$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP).bit

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
		if {[get_property part [current_project]] != \"$(VIVADO_PART)\"} { \n \
			set_property part \"$(VIVADO_PART)\" [current_project] \n \
		} \n \
		if {[get_property target_language [current_project]] != \"$(VIVADO_LANGUAGE)\"} { \n \
			set_property target_language \"$(VIVADO_LANGUAGE)\" [current_project] \n \
		} \n \
		proc update_files {target_fileset new_files} { \n \
			proc diff_files {a b} { \n \
				set r [list] \n \
				foreach f \$$a { \n \
					if {![lsearch -exact \$$b \$$f]} { \n \
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
		$(foreach l,$(VIVADO_DSN_LIB),update_files sources_1 {$(VIVADO_DSN_SRC.$l)} \n) \
		$(foreach l,$(VIVADO_DSN_LIB),update_files sim_1     {$(VIVADO_SIM_SRC.$l)} \n) \
		foreach f [get_files *.vh*] { \n \
			set current_type [get_property file_type [get_files \$$f]] \n \
			if {\"$(VIVADO_VHDL_LRM)\" == \"2002\"} { \n \
				set desired_type \"VHDL\" \n \
			} else { \n \
				set desired_type [concat \"VHDL \" \"$(VIVADO_VHDL_LRM)\"] \n \
			} \n \
			if {\"\$$current_type\" != \"\$$desired_type\"} { \n \
				set_property file_type \"\$$desired_type\" \$$f \n \
			} \n \
		} \n \
		proc type_sources {s} { \n \
			foreach file_type \$$s { \n \
				if {[string first \"=\" \"\$$file_type\"] != -1} { \n \
					set file [lindex [split \"\$$file_type\" \"=\"] 0] \n \
					set type [string map {\"-\" \" \"} [lindex [split \"\$$file_type\" \"=\"] 1]] \n \
					if {\$$type == \"VHDL 2002\"} { \n \
						set type \"VHDL\" \n \
					} \n \
					set_property file_type \"\$$type\" [get_files \"\$$file\"] \n \
				} \n \
			} \n \
		} \n \
		$(foreach l,$(VIVADO_DSN_LIB),type_sources {$(VIVADO_DSN_SRC.$l)} \n) \
		$(foreach l,$(VIVADO_SIM_LIB),type_sources {$(VIVADO_SIM_SRC.$l)} \n) \
		if {[get_property top [get_filesets sources_1]] != \"$(VIVADO_DSN_TOP)\"} { \n \
			set_property top \"$(VIVADO_DSN_TOP)\" [get_filesets sources_1] \n \
		} \n \
		if {[get_property top [get_filesets sim_1]] != \"$(VIVADO_SIM_TOP)\"} { \n \
			set_property top \"$(VIVADO_SIM_TOP)\" [get_filesets sim_1] \n \
		} \n \
		if {[get_property STEPS.SYNTH_DESIGN.ARGS.ASSERT [get_runs synth_1]]} { \n \
			set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1] \n \
		} \n \
		update_files constrs_1 {$(VIVADO_XDC_FILES)} \n \
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
