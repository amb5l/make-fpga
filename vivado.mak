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
VIVADO_PROJ_TEMP?=fpga_temp
ifdef VIVADO_DSN_SRC
ifdef VIVADO_DSN_LIB
$(error Cannot define both VIVADO_DSN_SRC and VIVADO_DSN_LIB)
endif
VIVADO_DSN_LIB=work
VIVADO_DSN_SRC.work=$(VIVADO_DSN_SRC)
endif

# checks
$(call check_option,VIVADO_LANGUAGE,VHDL-1993 VHDL-2008 VHDL-2019 Verilog)
$(foreach l,$(VIVADO_DSN_LIB),$(call check_defined,VIVADO_DSN_SRC.$l))
$(call check_defined_alt,VIVADO_DSN_TOP VIVADO_SIM_TOP)

# local definitions
VIVADO_RUN_TCL=run.tcl
VIVADO_RUN=\
	@cd $(VIVADO_DIR) && \
	printf "set code [catch {\n$1\n} result]\nputs \$$result\nexit \$$code\n" > $(VIVADO_RUN_TCL) && \
	$(VIVADO) -mode tcl -notrace -nolog -nojournal -source $(VIVADO_RUN_TCL)
VIVADO_XPR?=$(VIVADO_PROJ).xpr
VIVADO_DSN_BD_SRC_DIR=$(VIVADO_PROJ).srcs/sources_1/bd
VIVADO_DSN_BD_GEN_DIR?=$(VIVADO_PROJ).gen/sources_1/bd
VIVADO_DSN_BD=$(foreach x,$(VIVADO_DSN_BD_TCL),$(VIVADO_DSN_BD_SRC_DIR)/$(basename $(notdir $x))/$(basename $(notdir $x)).bd)
VIVADO_DSN_BD_HWDEF=$(foreach x,$(VIVADO_DSN_BD),$(VIVADO_DSN_BD_GEN_DIR)/$(basename $(notdir $x))/synth/$(basename $(notdir $x)).hwdef)
VIVADO_XSA=$(VIVADO_DSN_TOP).xsa
VIVADO_SYNTH_DCP=$(VIVADO_PROJ).runs/synth_1/$(VIVADO_DSN_TOP).dcp
VIVADO_IMPL_DCP=$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP)_routed.dcp
VIVADO_BIT=$(VIVADO_PROJ).runs/impl_1/$(VIVADO_DSN_TOP).bit

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

################################################################################
# rules and recipes

# project directory
$(VIVADO_DIR):
	@bash -c "mkdir -p $@"

# project file
$(VIVADO_DIR)/$(VIVADO_XPR): vivado_force | $(VIVADO_DIR)
	$(call banner,Vivado: create/update project)
	@cd $(VIVADO_DIR) && \
	rm -f $(VIVADO_PROJ_TEMP).xpr && \
	if [ -f $(VIVADO_PROJ).xpr ]; then \
		cp -p $(VIVADO_PROJ).xpr $(VIVADO_PROJ_TEMP).xpr; \
	fi
	$(call VIVADO_RUN, \
		if {[file exists $(VIVADO_XPR)]} { \n \
			puts \"opening project...\" \n \
			open_project \"$(basename $(VIVADO_XPR))\" \n \
		} else { \n \
			puts \"creating new project...\" \n \
			create_project $(if $(VIVADO_PART),-part \"$(VIVADO_PART)\") -force \"$(VIVADO_PROJ)\" \n \
		} \n \
		if {\"$(VIVADO_SIM_RUN)\" != \"\"} { \n \
			puts \"adding/updating simulation filesets...\" \n \
			foreach r {$(VIVADO_SIM_RUN)} { \n \
				set run [lindex [split \"\$$r\" \":\"] 0] \n \
				if {!(\"\$$run\" in [get_filesets])} { \n \
					create_fileset -simset \$$run \n \
				} \n \
				set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets \$$run] \n \
			} \n \
			current_fileset -simset [get_filesets $(word 1,$(VIVADO_SIM_RUNS))] \n \
		} \n \
		foreach s [get_filesets] { \n \
			if {!(\"$s\" in {$(VIVADO_SIM_RUNS)})} { \n \
				delete_fileset $s \n \
				} \n \
			} \n \
		} \n \
		puts \"checking/setting part...\" \n \
		if {\"$(VIVADO_PART)\" != \"\"} { \n \
			if {[get_property part [current_project]] != \"$(VIVADO_PART)\"} { \n \
				set_property part \"$(VIVADO_PART)\" [current_project] \n \
			} \n \
		} \n \
		puts \"checking/setting target language...\" \n \
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
				set missing_files [diff_files \$$new_files \$$current_files] \n \
				if {[llength \$$missing_files]} { \n \
					add_files -norecurse -fileset [get_filesets \$$target_fileset] \$$missing_files \n \
				} \n \
				set l [diff_files \$$current_files \$$new_files] \n \
				set surplus_files [list] \n \
				set exclude {.bd .xci} \n \
				foreach f \$$l { \n \
					if {!([file extension \$$f] in \$$exclude) && !([string first \"$(VIVADO_DIR)/$(VIVADO_DSN_BD_GEN_DIR)/\" \$$f] != -1)} { \n \
						lappend surplus_files \$$f \n \
					} \n \
				} \n \
				if {[llength \$$surplus_files]} { \n \
					remove_files -fileset \$$target_fileset \$$surplus_files \n \
				} \n \
			} else { \n \
				add_files -norecurse -fileset [get_filesets \$$target_fileset] \$$new_files \n \
			} \n \
		} \n \
		puts \"adding/updating design sources...\" \n \
		$(foreach l,$(VIVADO_DSN_LIB),update_files sources_1 {$(call VIVADO_SRC_FILE,$(VIVADO_DSN_SRC.$l))} \n) \
		puts \"adding/updating simulation sources...\" \n \
		$(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB.$r),update_files $r {$(call VIVADO_SRC_FILE,$(VIVADO_SIM_SRC.$l.$r))} \n)) \
		foreach f [get_files *.vh*] { \n \
			if {[string first \"$(VIVADO_DIR)/$(VIVADO_PROJ).gen/sources_1/bd/\" \$$f] == -1} { \n \
				set current_type [get_property file_type [get_files \$$f]] \n \
				set desired_type [string map {\"-\" \" \"} \"$(VIVADO_LANGUAGE)\"] \n \
				if {\$$desired_type == \"VHDL 1993\"} { \n \
					set desired_type \"VHDL\" \n \
				} \n \
				if {\"\$$current_type\" != \"\$$desired_type\"} { \n \
					set_property file_type \"\$$desired_type\" \$$f \n \
				} \n \
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
		puts \"checking/setting design source file types...\" \n \
		$(foreach l,$(VIVADO_DSN_LIB),type_sources sources_1 {$(call VIVADO_SRC_FILE,$(VIVADO_DSN_SRC.$l))} \n) \
		puts \"checking/setting simulation source file types...\" \n \
		$(foreach r,$(VIVADO_SIM_RUNS),$(foreach l,$(VIVADO_SIM_LIB),type_sources $r {$(call VIVADO_SRC_FILE,$(VIVADO_SIM_SRC.$l.$r))} \n)) \
		puts \"checking/setting top design unit...\" \n \
		if {\"$(VIVADO_DSN_TOP)\" != \"\"} { \n \
			if {[get_property top [get_filesets sources_1]] != \"$(VIVADO_DSN_TOP)\"} { \n \
				set_property top \"$(VIVADO_DSN_TOP)\" [get_filesets sources_1] \n \
			} \n \
		} \n \
		if {\"$(VIVADO_SIM_RUN)\" != \"\"} { \n \
			puts \"checking/setting top unit and generics for simulation filesets...\" \n \
		} \n \
		foreach r {$(VIVADO_SIM_RUN)} { \n \
			set run [lindex [split [lindex [split \"\$$r\" \";\"] 0] \":\"] 0] \n \
			set top [lindex [split [lindex [split [lindex [split \"\$$r\" \";\"] 0] \":\"] 1] \"$(comma)\"] 0] \n \
			set gen [split [lindex [split \"\$$r\" \";\"] 1] \"$(comma)\"] \n \
			set_property top \$$top [get_filesets \$$run] \n \
			set_property generic \$$gen [get_filesets \$$run] \n \
		} \n \
		puts \"checking/enabling synthesis assertions...\" \n \
		set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1] \n \
		if {\"$(VIVADO_XDC)\" != \"\"} { \n \
			puts \"adding/updating constraints...\" \n \
		} \n \
		$(if $(VIVADO_XDC),update_files constrs_1 {$(call VIVADO_SRC_FILE,$(VIVADO_XDC))} \n) \
		proc scope_constrs {xdc} { \n \
			foreach x \$$xdc { \n \
				set file  [lindex [split \"\$$x\" \"=\"] 0] \n \
				set scope [lindex [split \"\$$x\" \"=\"] 1] \n \
				set_property used_in_synthesis      [expr [string first \"SYNTH\" \"\$$scope\"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] \$$file] \n \
				set_property used_in_implementation [expr [string first \"IMPL\"  \"\$$scope\"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] \$$file] \n \
				set_property used_in_simulation     [expr [string first \"SIM\"   \"\$$scope\"] != -1 ? true : false] [get_files -of_objects [get_filesets constrs_1] \$$file] \n \
			} \n \
		} \n \
		if {\"$(VIVADO_XDC)\" != \"\"} { \n \
			puts \"checking/scoping constraints...\" \n \
		} \n \
		scope_constrs {$(VIVADO_XDC)} \n \
		exit 0 \
	)
	@cd $(VIVADO_DIR) && \
	if [ -f $(VIVADO_PROJ_TEMP).xpr ]; then \
		if cmp -s $(VIVADO_PROJ).xpr $(VIVADO_PROJ_TEMP).xpr; then \
			printf "$(col_fg_cyn)project unchanged$(col_rst)\n"; \
			rm -f $(VIVADO_PROJ).xpr; \
			cp -p $(VIVADO_PROJ_TEMP).xpr $(VIVADO_PROJ).xpr; \
			rm -f $(VIVADO_PROJ_TEMP).xpr; \
		else \
			printf "$(col_fg_yel)project updated$(col_rst)\n"; \
			rm -f $(VIVADO_PROJ_TEMP).xpr; \
		fi; \
	else \
		printf "$(col_fg_grn)project created$(col_rst)\n"; \
	fi

# block diagrams
define RR_VIVADO_BD
$(VIVADO_DIR)/$(VIVADO_DSN_BD_SRC_DIR)/$(basename $(notdir $1))/$(basename $(notdir $1)).bd: $1 $(VIVADO_DIR)/$(VIVADO_XPR)
	$(call banner,Vivado: create block diagrams)
	$$(call VIVADO_RUN, \
		open_project $$(VIVADO_PROJ) \n \
		if {[get_files -quiet -of_objects [get_filesets sources_1] $(basename $(notdir $1)).bd] != \"\"} { \n \
			export_ip_user_files -of_objects [get_files -of_objects [get_filesets sources_1] $(basename $(notdir $1)).bd] -no_script -reset -force -quiet \n \
			remove_files [get_files -of_objects [get_filesets sources_1] $(basename $(notdir $1)).bd] \n \
			file delete -force $(VIVADO_DSN_BD_SRC_DIR)/$(basename $(notdir $1)) \n \
			file delete -force $(VIVADO_DSN_BD_GEN_DIR)/$(basename $(notdir $1)) \n \
		} \n \
		source $1 \n \
	)
endef
$(foreach x,$(VIVADO_DSN_BD_TCL),$(eval $(call RR_VIVADO_BD,$x)))

# block diagram hardware definitions
define RR_VIVADO_BD_GEN
$(VIVADO_DIR)/$(VIVADO_DSN_BD_GEN_DIR)/$(basename $(notdir $1))/synth/$(basename $(notdir $1)).hwdef: $(VIVADO_DIR)/$1
	$(call banner,Vivado: generate block diagram hardware definitions)
	$$(call VIVADO_RUN, \
		open_project $$(VIVADO_PROJ) \n \
		generate_target all [get_files -of_objects [get_filesets sources_1] $$(notdir $$<)] \n \
	)
endef
$(foreach x,$(VIVADO_DSN_BD),$(eval $(call RR_VIVADO_BD_GEN,$x)))

# hardware handoff (XSA) file
$(VIVADO_DIR)/$(VIVADO_XSA): $(addprefix $(VIVADO_DIR)/,$(VIVADO_DSN_BD_HWDEF))
	$(call banner,Vivado: create hardware handoff (XSA) file)
	$(call VIVADO_RUN, \
		open_project $(VIVADO_PROJ) \n \
		write_hw_platform -fixed -force -file $(VIVADO_DSN_TOP).xsa \n \
	)

# synthesis
$(VIVADO_DIR)/$(VIVADO_SYNTH_DCP): $(foreach l,$(VIVADO_DSN_LIB),$(VIVADO_DSN_SRC.$l)) $(VIVADO_DSN_XDC_SYNTH) $(VIVADO_DSN_XDC) $(VIVADO_DSN_BD_HWDEF) $(VIVADO_DIR)/$(VIVADO_XPR)
	$(call banner,Vivado: synthesis)
	$(call VIVADO_RUN, \
		open_project $(VIVADO_PROJ) \n \
		reset_run synth_1 \n \
		launch_runs synth_1 -jobs $jobs \n \
		wait_on_run synth_1 \n \
		if {[get_property PROGRESS [get_runs synth_1]] != \"100%\"} {exit 1} \n \
	)

# implementation (place and route) and preparation for simulation
# NOTE: implementation changes BD timestamp which upsets dependancies,
#  so we force BD modification time backwards
$(VIVADO_DIR)/$(VIVADO_IMPL_DCP): $(VIVADO_DSN_XDC_IMPL) $(VIVADO_DSN_ELF) $(VIVADO_SIM_ELF) $(VIVADO_DIR)/$(VIVADO_SYNTH_DCP)
	$(call banner,Vivado: implementation)
	$(call VIVADO_RUN, \
		open_project $(VIVADO_PROJ) \n \
		reset_run impl_1 \n \
		launch_runs impl_1 -to_step route_design \n \
		wait_on_run impl_1 \n \
		if {[get_property PROGRESS [get_runs impl_1]] != \"100%\"} {exit 1} \n \
	)

# write bitstream
$(VIVADO_DIR)/$(VIVADO_BIT): $(VIVADO_DIR)/$(VIVADO_IMPL_DCP)
	$(call banner,Vivado: write bitstream)
	$(call VIVADO_RUN, \
		open_project $(VIVADO_PROJ) \n \
		reset_run impl_1 \n \
		launch_runs impl_1 -to_step write_bitstream \n \
		wait_on_run impl_1 \n \
		if {[get_property PROGRESS [get_runs impl_1]] != \"100%\"} {exit 1} \n \
	)

# simulation runs
define rr_simrun
$(call VIVADO_SIM_LOG,$1): vivado_force $(VIVADO_DIR)/$(VIVADO_XPR)
	$$(call banner,Vivado: simulation run = $1)
	$$(call VIVADO_RUN, \
		open_project $$(VIVADO_PROJ) \n \
		current_fileset -simset [get_filesets $1] \n \
		launch_simulation \n \
		run all \n \
	)
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
