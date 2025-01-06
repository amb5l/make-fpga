################################################################################
# vivado_post.mak
# Support for creating post synthesis/implementation netlists with Vivado.
# See https://github.com/amb5l/make-fpga
################################################################################
# User makefile variables:
#   VIVADO_POST_UNIT                 list of design units
#   VIVADO_POST_SRC.<unit>           list of sources for <unit>
#   VIVADO_POST_GEN.<unit>           list of generics for <unit>
# Created variables:
#   VIVADO_POST_SYN_FUNC.<unit>.vhd  path to post synthesis functional VHDL netlist
################################################################################

include $(dir $(lastword $(MAKEFILE_LIST)))/common.mak

VIVADO_POST_DIR?=vivado_post
VIVADO_POST_PROJ?=post
VIVADO_POST_LANGUAGE?=VHDL
VIVADO_POST_VHDL_LRM?=2008
VIVADO_POST_WORK?=work

# checks
$(call check_defined,XILINX_VIVADO)
$(foreach u,$(VIVADO_POST_UNIT),$(if $(VIVADO_POST_SRC.$u),,$(error $(VIVADO_POST_SRC.$u) not defined)))
$(if $(filter 2000 2008,$(VIVADO_POST_VHDL_LRM)),,$(error VIVADO_VHDL_LRM value is unsupported: $(VIVADO_POST_VHDL_LRM)))
$(foreach u,$(VIVADO_POST_UNIT),$(foreach s,$(VIVADO_POST_SRC.$u),$(if $(filter 2000 2008,$(call get_src_lrm,$s,$(VIVADO_POST_VHDL_LRM))),,$(error source file LRM is unsupported: $s))))

################################################################################
# TCL sequences

vivado_post_scripts+=vivado_post_xpr_tcl
define vivado_post_xpr_tcl
	set top [lindex $$argv 0]
	set src_spec [lrange $$argv 1 end]
	create_project -force "$(VIVADO_POST_PROJ)"
	puts "setting target language..."
	set_property target_language "$(VIVADO_POST_LANGUAGE)" [current_project]
	puts "adding design sources, assigning libraries, and setting language defaults/overrides..."
	foreach src_spec [lrange $$argv 1 end] {
		set src_file_lib [split $$src_spec ";"]
		set src_file [lindex [split $$src_file_lib "="] 0]
		set src_lib [lindex [split $$src_file_lib "="] 1]
		if {$$src_lib == ""} {
			set src_lib "$(VIVADO_POST_WORK)"
		}
		set src_lang [lindex [split $$src_spec ";"] 1]
		if {$$src_lang == ""} {
			if {[string range [file extension $$src_file] 0 2] == ".vh"} {
				if {"$(VIVADO_POST_VHDL_LRM)" == "2008"} {
					set src_lang "VHDL-2008"
				} else {
					set src_lang "VHDL-2000"
				}
			} else {
				set src_lang "Verilog"
			}
		}
		set src_lang [string map {"-" " "} $$src_lang]
		if {$$src_lang == "VHDL 2000"} {
			set src_lang "VHDL"
		}
		add_files -norecurse -fileset [get_filesets sources_1] $$src_file
		set_property library $$src_lib [get_files -of_objects [get_filesets sources_1] $$src_file]
		set_property file_type $$src_lang [get_files -of_objects [get_filesets sources_1] $$src_file]
	}
	puts "setting top design unit..."
	set_property top $$top [get_filesets sources_1]
	puts "enabling synthesis assertions..."
	set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]
	exit 0
endef

vivado_post_scripts+=vivado_post_gen_tcl
define vivado_post_gen_tcl
	if {$$argv != ""} {
		puts "setting top design unit generics..."
		set_property generic $$argv [get_filesets sources_1]
	} else {
		puts "no top design unit generics specified"
	}
endef

vivado_post_scripts+=vivado_post_syn_func_vhd_tcl
define vivado_post_syn_func_vhd_tcl
	open_project $(VIVADO_POST_PROJ)
	set outfile [lindex $$argv 0]
	set top [lindex $$argv 1]
	foreach src_spec [lrange $$argv 2 end] {
		set src_file_lib [split $$src_spec ";"]
		set src_file [lindex [split $$src_file_lib "="] 0]
		set src_lib [lindex [split $$src_file_lib "="] 1]
		if {$$src_lib == ""} {
			set src_lib "$(VIVADO_POST_WORK)"
		}
		set src_lang [lindex [split $$src_spec ";"] 1]
		if {$$src_lang == ""} {
			if {[string range [file extension $$src_file] 0 2] == ".vh"]} {
				if {"$(VIVADO_POST_VHDL_LRM)" == "2008"} {
					set src_lang "VHDL-2008"
				} else {
					set src_lang "VHDL-2000"
				}
			} else {
				set src_lang "Verilog"
			}
		}
		set src_lang [string map {"-" " "} $$src_lang]
		if {$$src_lang == "VHDL 2000"} {
			set src_lang "VHDL"
		}
		set vhdl2008 ""
		if {$$src_lang == "VHDL 2008"} {
			set vhdl2008 "-vhdl2008"
		}
		read_vhdl -library $$src_lib $$vhdl2008 $$src_file
	}
	synth_design -top $$top
	puts "writing netlist..."
	write_vhdl -force $$outfile
endef

################################################################################
# create directory and write script files

$(shell $(MKDIR) -p $(VIVADO_POST_DIR))
$(foreach s,$(vivado_post_scripts),\
	$(file >$(VIVADO_POST_DIR)/$(subst _tcl,.tcl,$s),set code [catch { $($s) } result]; puts $$result; exit $$code) \
)

################################################################################
# rules and recipes

define RR_VIVADO_POST

$$(VIVADO_POST_DIR)/$$(VIVADO_POST_PROJ).xpr: $$(if $$(filter dev,$$(MAKECMDGOALS)),,$$(MAKEFILE_LIST)) | $$(call get_src_file,$$(VIVADO_POST_SRC.$1))
	$(call banner,Vivado Post Synthesis/Implementation Netlist Support: create project)
	@rm -f $$@
	@cd $$(dir $$@) && vivado \
		-nolog -nojou -notrace -mode batch \
		-source vivado_post_xpr.tcl \
		-tclargs \
		$1 \
		$$(call get_src_file,$$(VIVADO_POST_SRC.$1))
	@cd $$(dir $$@) && vivado \
		-nolog -nojou -notrace -mode batch \
		-source vivado_post_gen.tcl \
		-tclargs \
		$(VIVADO_POST_GEN.$1)

VIVADO_POST_SYN_FUNC.$1.vhd=$$(abspath $$(VIVADO_POST_DIR)/$1_post_syn_func.vhd)
$$(VIVADO_POST_SYN_FUNC.$1.vhd): $$(call get_src_file,$$(VIVADO_POST_SRC.$1)) $$(VIVADO_POST_DIR)/$$(VIVADO_POST_PROJ).xpr
	$(call banner,Vivado Post Synthesis/Implementation Netlist Support: create netlist)
	@cd $$(dir $$@) && vivado \
		-nolog -nojou -notrace -mode batch \
		-source vivado_post_syn_func_vhd.tcl \
		-tclargs \
		$$(notdir $$@) \
		$1 \
		$^
endef

$(foreach u,$(VIVADO_POST_UNIT),$(eval $(call RR_VIVADO_POST,$u)))

################################################################################

clean::
	@rm -rf $(VIVADO_POST_DIR)
