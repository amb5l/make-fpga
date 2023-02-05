set args $argv
set tool [lindex $argv 0]
set args [lrange $args 1 end]
switch $tool {

	eval {
		set r [eval [join $args " "]]
		puts $r
		return $r
	}

	vivado {

		set code [catch {

			proc error_exit {msgs} {
				puts stderr "make_fpga.tcl: vivado: ERROR - details to follow..."
				foreach msg $msgs {
					puts stderr $msg
				}
				exit 1
			}

			proc params_to_dict {p} {
				set d [dict create]
				while (1) {
					while (1) {
						set key [lindex $p 0]
						set c [string index $key end]
						if {$c == ""} {
							break
						}
						set p [lrange $p 1 end]
						if {$c == ":"} {
							set key [string range $key 0 end-1]
							break
						}
					}
					if {$key == ""} {
						break
					}
					set values []
					while (1) {
						set c [string index [lindex $p 0] end]
						if {$c == "" || $c == ":"} {
							break
						} else {
							lappend values [lindex $p 0]
							set p [lrange $p 1 end]
						}
					}
					if {[llength $values] > 0} {
						foreach value $values {
							dict lappend d $key $value
						}
					}
				}
				return $d
			}

			set proj_name [lindex $args 0]
			set cmd [lindex $args 1]
			set args [lrange $args 2 end]
			switch $cmd {

				create {
					# create fpga_part proj_lang [[cat: cat_items] [cat: cat_items]...]
					set fpga_part [lindex $args 0]
					set proj_lang [lindex $args 1]
					set args [lrange $args 2 end]
					set d [params_to_dict $args]
					if {[string equal $fpga_part "none"]} {
						create_project -force $proj_name
					} else {
						create_project -part $fpga_part -force $proj_name
					}
					set_property target_language $proj_lang [get_projects $proj_name]
					set_property -name "target_language" -value "VHDL" -objects [current_project]
					if {[dict exist $d dsn_vhdl]} {
						add_files -norecurse -fileset [get_filesets sources_1] [dict get $d dsn_vhdl]
						set d [dict remove $d dsn_vhdl]
					}
					if {[dict exist $d dsn_vhdl_2008]} {
						set_property -name "enable_vhdl_2008" -value "1" -objects [current_project]
						add_files -norecurse -fileset [get_filesets sources_1] [dict get $d dsn_vhdl_2008]
						set_property file_type "VHDL 2008" [get_files -of_objects [get_filesets sources_1] [dict get $d dsn_vhdl_2008]]
						set d [dict remove $d dsn_vhdl_2008]
					}
					if {[dict exist $d dsn_xdc]} {
						add_files -norecurse -fileset [get_filesets constrs_1] [dict get $d dsn_xdc]
						set_property used_in_synthesis true [get_files -of_objects [get_filesets constrs_1] [dict get $d dsn_xdc]]
						set_property used_in_implementation true [get_files -of_objects [get_filesets constrs_1] [dict get $d dsn_xdc]]
						set d [dict remove $d dsn_xdc]
					}
					if {[dict exist $d dsn_xdc_synth]} {
						add_files -norecurse -fileset [get_filesets constrs_1] [dict get $d dsn_xdc_synth]
						set_property used_in_synthesis true [get_files -of_objects [get_filesets constrs_1] [dict get $d dsn_xdc_synth]]
						set_property used_in_implementation false [get_files -of_objects [get_filesets constrs_1] [dict get $d dsn_xdc_synth]]
						set d [dict remove $d dsn_xdc_synth]
					}
					if {[dict exist $d dsn_xdc_impl]} {
						puts "dict get d dsn_xdc_impl = [dict get $d dsn_xdc_impl]"
						add_files -norecurse -fileset [get_filesets constrs_1] [dict get $d dsn_xdc_impl]
						puts "debug"
						puts "files : [get_files -of_objects [get_filesets constrs_1] [dict get $d dsn_xdc_impl]]"
						set_property used_in_synthesis false [get_files -of_objects [get_filesets constrs_1] [dict get $d dsn_xdc_impl]]
						puts "debug"
						set_property used_in_implementation true [get_files -of_objects [get_filesets constrs_1] [dict get $d dsn_xdc_impl]]
						puts "debug"
						set d [dict remove $d dsn_xdc_impl]
					}
					foreach f [get_files -of_objects [get_filesets constrs_1] *.tcl] {
						set_property used_in_simulation false [get_files -of_objects [get_filesets constrs_1] $f]
					}
					if {[dict exist $d dsn_top]} {
						set_property top [lindex [dict get $d dsn_top] 0] [get_filesets sources_1]
						set d [dict remove $d dsn_top]
					}
					if {[dict exist $d dsn_gen]} {
						set g [dict get $d dsn_gen]
						set s "set_property generic {"
						while {[llength $g] >= 2} {
							append s "[lindex $g 0]=[lindex $g 1] "
							set g [lrange $g 2 end]
						}
						append s "} [get_filesets sources_1]"
						eval $s
						set d [dict remove $d dsn_gen]
					}
					if {[dict exist $d sim_vhdl]} {
						add_files -norecurse -fileset [get_filesets sim_1] [dict get $d sim_vhdl]
						set d [dict remove $d sim_vhdl]
					}
					if {[dict exist $d sim_vhdl_2008]} {
						add_files -norecurse -fileset [get_filesets sim_1] [dict get $d sim_vhdl_2008]
						set_property file_type "VHDL 2008" [get_files -of_objects [get_filesets sim_1] [dict get $d sim_vhdl_2008]]
						set d [dict remove $d sim_vhdl_2008]
					}
					if {[dict exist $d sim_top]} {
						set_property top [lindex [dict get $d sim_top] 0] [get_filesets sim_1]
						set d [dict remove $d sim_top]
					}
					if {[dict exist $d sim_gen]} {
						set g [dict get $d sim_gen]
						set s "set_property generic {"
						while {[llength $g] >= 2} {
							append s "[lindex $g 0]=[lindex $g 1] "
							set g [lrange $g 2 end]
						}
						append s "} [get_filesets sim_1]"
						eval $s
						set d [dict remove $d sim_gen]
					}
					if {[llength [dict keys $d]]} {
						error_exit {"create - leftovers: $d"}
					}

				}

				build {
					# build target ...
					set target [lindex $args 0]
					open_project $proj_name
					switch $target {
						ip {
							# build ip tcl_file [simulation models]
							set xci_file [lindex $args 1]
							set tcl_file [lindex $args 2]
							set args [lrange $args 3 end]
							if {$xci_file in [get_files $xci_file]} {
								remove_files $xci_file
							}
							source $tcl_file
							if {[llength $args] > 0} {
								add_files -norecurse -fileset [get_filesets sim_1] $args
							}
						}
						bd {
							# build bd bd_file tcl_file
							set bd_file [lindex $args 1]
							set tcl_file [lindex $args 2]
							if {$bd_file in [get_files $bd_file]} {
								remove_files $bd_file
							}
							source $tcl_file
						}
						hwdef {
							# build hwdef filename
							set filename [lindex $args 1]
							generate_target all [get_files -of_objects [get_filesets sources_1] $filename]
						}
						xsa {
							# build xsa
							set top [get_property top [get_filesets sources_1]]
							write_hw_platform -fixed -force -file $top.xsa
						}
						synth {
							# build synth jobs
							set jobs [lindex $args 1]
							reset_run synth_1
							launch_runs synth_1 -jobs $jobs
							wait_on_run synth_1
							if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
								error_exit {"synthesis did not complete"}
							}
						}
						impl {
							# build impl jobs [proc_inst proc_ref proc_elf]
							set jobs [lindex $args 1]
							if {[llength $args] >= 3} {
								set proc_inst [lindex $args 2]
							}
							if {[llength $args] >= 4} {
								set proc_ref [lindex $args 3]
							}
							if {[llength $args] >= 5} {
								set proc_elf [lindex $args 4]
								if {[llength [get_files -all -of_objects [get_fileset sources_1] $proc_elf]] == 0} {
									add_files -norecurse -fileset [get_filesets sources_1] $proc_elf
									set_property SCOPED_TO_REF $proc_ref [get_files -of_objects [get_filesets sources_1] $proc_elf]
									set_property SCOPED_TO_CELLS $proc_inst [get_files -of_objects [get_filesets sources_1] $proc_elf]
								}
							}
							reset_run impl_1
							launch_runs impl_1 -jobs $jobs
							wait_on_run impl_1
							if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
								error_exit {"implementation did not complete"}
							}
						}
						bit {
							# build bit filename
							set filename [lindex $args 1]
							open_run impl_1
							write_bitstream -force "$filename"
						}
						bd_tcl {
							# update bd_tcl tcl_file bd_file
							set tcl_file [lindex $args 1]
							set bd_file [lindex $args 2]
							open_bd_design $bd_file
							write_bd_tcl -force -include_layout $tcl_file
						}
						bd_svg {
							# update bd_svg svg_file bd_file
							set svg_file [lindex $args 1]
							set bd_file [lindex $args 2]
							open_bd_design $bd_file
							write_bd_layout -force -format svg $svg_file
						}
						default {
							error_exit {"build - unknown target ($target)"}
						}
					}
				}

				simprep {
					# simprep [gen: generic value] [elf: proc_inst proc_ref proc_elf]
					set d [params_to_dict $args]
					open_project $proj_name
					set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]
					if {[dict exist $d gen]} {
						set g [dict get $d gen]
						set s "set_property generic {"
						while {[llength $g] >= 2} {
							append s "[lindex $g 0]=[lindex $g 1] "
							set g [lrange $g 2 end]
						}
						append s "} [get_filesets sim_1]"
						eval $s
					}
					if {[dict exist $d elf]} {
						set proc_inst [lindex [dict get $d elf] 0]
						set proc_ref [lindex [dict get $d elf] 1]
						set proc_elf [lindex [dict get $d elf] 2]
						if {[llength [get_files -all -of_objects [get_fileset sim_1] $proc_elf]] == 0} {
							add_files -norecurse -fileset [get_filesets sim_1] $proc_elf
							set_property SCOPED_TO_REF $proc_ref [get_files -all -of_objects [get_fileset sim_1] $proc_elf]
							set_property SCOPED_TO_CELLS { $proc_inst } [get_files -all -of_objects [get_fileset sim_1] $proc_elf]
						}
					}
				}

				prog {
					# prog file
					set file [lindex $args 0]
					open_hw
					connect_hw_server
					current_hw_target [lindex [get_hw_targets] 0]
					open_hw_target
					current_hw_device [lindex [get_hw_devices] 0]
					set_property PROGRAM.FILE $file [current_hw_device]
					program_hw_devices [current_hw_device]
				}

				simulate {
					# simulate [gen: generic value] [elf: proc_inst proc_ref proc_elf] [vcd: filename]
					set d [params_to_dict $args]
					open_project $proj_name
					set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]
					if {[dict exist $d gen]} {
						set g [dict get $d gen]
						set s "set_property generic {"
						while {[llength $g] >= 2} {
							append s "[lindex $g 0]=[lindex $g 1] "
							set g [lrange $g 2 end]
						}
						append s "} [get_filesets sim_1]"
						eval $s
					}
					if {[dict exist $d elf]} {
						set proc_inst [lindex [dict get $d elf] 0]
						set proc_ref [lindex [dict get $d elf] 1]
						set proc_elf [lindex [dict get $d elf] 2]
						if {[llength [get_files -all -of_objects [get_fileset sim_1] $proc_elf]] == 0} {
							add_files -norecurse -fileset [get_filesets sim_1] $proc_elf
							set_property SCOPED_TO_REF $proc_ref [get_files -all -of_objects [get_fileset sim_1] $proc_elf]
							set_property SCOPED_TO_CELLS { $proc_inst } [get_files -all -of_objects [get_fileset sim_1] $proc_elf]
						}
					}
					launch_simulation
					if {[dict exist $d vcd]} {
						set vcd_filename [lindex [dict get $d vcd] 0]
						open_vcd $vcd_filename
						log_vcd [get_objects -r /*]
					}
					set t_start [clock seconds]
					run all
					set t_end [clock seconds]
					if {[dict exist $d vcd]} {
						flush_vcd
						close_vcd
					}
					set elapsed_time [expr {$t_end-$t_start}]
					puts "elapsed time == $elapsed_time"
				}

				default {
					error_exit {"unknown command: $cmd"}
				}

			}
		} result]
		puts $result
		exit $code
	}

	vitis {

		set code [catch {

			package require fileutil

			proc error_exit {msgs} {
				puts stderr "make_fpga.tcl: vitis: ERROR - details to follow..."
				foreach msg $msgs {
					puts stderr $msg
				}
				exit 1
			}

			set app_name [lindex $args 0]
			set cmd [lindex $args 1]
			set args [lrange $args 2 end]
			switch $cmd {

				create {
					# create xsa_file proc [cat: cat_items]
					set xsa_file [lindex $args 1]
					set proc [lindex $args 2]
					set args [lrange $args 3 end]
					set d [dict create]
					while (1) {
						while (1) {
							set key [lindex $args 0]
							set c [string index $key end]
							if {$c == ""} {
								break
							}
							set args [lrange $args 1 end]
							if {$c == ":"} {
								set key [string range $key 0 end-1]
								break
							}
						}
						if {$key == ""} {
							break
						}
						set values []
						while (1) {
							set c [string index [lindex $args 0] end]
							if {$c == "" || $c == ":"} {
								break
							} else {
								lappend values [lindex $args 0]
								set args [lrange $args 1 end]
							}
						}
						if {[llength $values] > 0} {
							foreach value $values {
								dict lappend d $key $value
							}
						}
					}
					setws .
					app create -name $app_name -hw $xsa_file -os standalone -proc $proc -template {Empty Application(C)}
					if {[dict exist $d src]} {
						# importsources does not handle remote sources, so hack linked resources into .project as follows:
						set x [list "	<linkedResources>"]
						foreach filename [dict get $d src] {
							set basename [file tail $filename]
							set relpath [fileutil::relative [file normalize ./$app_name] $filename]
							set n 0
							while {[string range $relpath 0 2] == "../"} {
								set relpath [string range $relpath 3 end]
								incr n
							}
							if {n > 0} {
								set relpath "PARENT-$n-PROJECT_LOC/$relpath"
							}
							set s [list "		<link>"]
							lappend s "			<name>src/$basename</name>"
							lappend s "			<type>1</type>"
							lappend s "			<locationURI>$relpath</locationURI>"
							lappend s "		</link>"
							set x [concat $x $s]
						}
						lappend x "	</linkedResources>"
						set f [open "./${app_name}/.project" "r"]
						set lines [split [read $f] "\n"]
						close $f
						set i [lsearch $lines "	</natures>"]
						if {$i < 0} {
							error "did not find insertion point"
						}
						set lines [linsert $lines 1+$i {*}$x]
						set f [open "./${app_name}/.project" "w"]
						puts $f [join $lines "\n"]
						close $f
						set d [dict remove $d src]
					}
					if {[dict exist $d inc]} {
						foreach path [dict get $d inc] {
							app config -name $app_name build-config release
							app config -name $app_name include-path $path
							app config -name $app_name build-config debug
							app config -name $app_name include-path $path
						}
						set d [dict remove $d inc]
					}
					if {[dict exist $d inc_rls]} {
						foreach path [dict get $d inc_rls] {
							app config -name $app_name build-config release
							app config -name $app_name include-path $path
						}
						set d [dict remove $d inc_rls]
					}
					if {[dict exist $d inc_dbg]} {
						foreach path [dict get $d inc_dbg] {
							app config -name $app_name build-config debug
							app config -name $app_name include-path $path
						}
						set d [dict remove $d inc_dbg]
					}
					if {[dict exist $d sym]} {
						foreach sym [dict get $d sym] {
							app config -name $app_name build-config release
							app config -name $app_name define-compiler-symbols $sym
							app config -name $app_name build-config debug
							app config -name $app_name define-compiler-symbols $sym
						}
						set d [dict remove $d sym]
					}
					if {[dict exist $d sym_rls]} {
						foreach sym [dict get $d sym_rls] {
							app config -name $app_name build-config release
							app config -name $app_name define-compiler-symbols $sym
						}
						set d [dict remove $d sym_rls]
					}
					if {[dict exist $d sym_dbg]} {
						foreach sym [dict get $d sym_dbg] {
							app config -name $app_name build-config debug
							app config -name $app_name define-compiler-symbols $sym
						}
						set d [dict remove $d sym_dbg]
					}
					if {[llength [dict keys $d]]} {
						error_exit {"create - leftovers: $d"}
						exit 1
					}
				}

				build {
					set cfg [lindex $args 0]
					setws .
					app config -name $app_name build-config $cfg
					app build -name $app_name
				}

				default {
					error_exit {"unknown cmd ($cmd)"}
				}
			}
		} result]
		puts $result
		exit $code		
	}

	radiant {
		set cmd [lindex $argv 1]
		set args [lrange $argv 2 end]
		switch $cmd {
			script {
				set script [join $args " "]
				set r [eval $script]
				puts $r
				return $r
			}
			default {
				error {Unknown command: $cmd}
			}
		}

	}

	default {
		error {Unknown tool: $tool}
	}

}
