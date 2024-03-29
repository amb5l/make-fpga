################################################################################
# do_vsim.py
# A part of make-fpga - see https://github.com/amb5l/make-fpga
# This script generates TCL scripts to simulate FPGA designs with ModelSim etc.
################################################################################

import sys,os,argparse
from make_fpga import *

# parse arguments

parser = argparse.ArgumentParser(
    prog='do_vsim.py',
    description='Create makefiles for simulating FPGA designs with ModelSim/Questa/etc',
    epilog=help_run,
    formatter_class=argparse.RawDescriptionHelpFormatter
   )
parser.add_argument(
    '--path',
    help='path to tool binaries'
   )
parser.add_argument(
    '--lib',
    nargs='+',
    action='append',
    help='precompiled libraries'
   )
parser.add_argument(
    '--vhdl',
    choices=['1987','1993','2002','2008'],
    help='VHDL LRM version (defaults to 2008)',
    default='2008'
   )
parser.add_argument(
    '--work',
    help='work library (defaults to "work")',
    default='work'
   )
parser.add_argument(
    '--src',
    required=True,
    nargs='+',
    action='append',
    help='source(s) in compile order (append =LIB to specify library name)'
   )
parser.add_argument(
    '--run',
    required=True,
    nargs='+',
    action='append',
    help='simulation run specification(s) (see below)'
   )
parser.add_argument(
    '--gen',
    nargs='+',
    action='append',
    help='generics assignment(s) (applied to all runs)'
   )
parser.add_argument(
    '--sdf',
    nargs='+',
    action='append',
    help='SDF mapping(s) (applied to all runs)'
   )

args=parser.parse_args()
c,d=process_src(args.src,args.work)
runs=process_run(flatten(args.run))
args.lib=flatten(args.lib)
args.gen=process_gen(flatten(args.gen))
args.sdf=process_sdf(flatten(args.sdf))

# output

print('# TCL script generated by do_vsim.py (see https://github.com/amb5l/make-fpga)')
print('# for simulation using ModelSim/Questa/etc')

print('################################################################################')
print('# simulation specific definitions')
print('')
print('# list of source specs in compilation order')
print('# each source spec is a list containing library name and source file')
print('quietly set srcs {')
for l,s in c:
    print('  { '+l+' '+s+' '+'}')
print('}')
print('')
print('# list of generic assignments applied to all runs')
print('# each generic assignment is a list containing name and value')
print('quietly set gens {')
for n,v in args.gen:
    print(' { %s {%s} }' % (n,v))
print('}')
print('')
print('# list of SDF mappings applied to all runs')
print('# each SDF mapping is a list containing delay, design unit path and filename')
print('quietly set sdfs {')
for t,p,f in args.sdf:
    print(' { %s %s %s }' % (t,p,f))
print('}')
print('')
print('# list of simulation run specs')
print('# each run spec is a list containing name and run specifics:')
print('#  top design unit, generic assignment list and SDF mapping list')
print('quietly set runs {')
for r in runs:
    gen = ['{ '+n+' '+v+' }' for n,v in r[2]]
    sdf = ['{ '+t+' '+p.replace('//','/')+' '+f+' }' for t,p,f in r[3]]
    print(' { '+r[0]+' '+r[1]+' { '+' '.join(gen)+' } { '+' '+' '.join(sdf)+' } }')
print('}')
print('')
print('# list of precompiled libraries to use')
print('quietly set libs { '+' '.join(args.lib)+' }')
print('')
print('# work library name')
print('quietly set work "'+args.work+'"')
print('')
print('# VHDL LRM version')
print('quietly set vhdl "'+args.vhdl+'"')
print('')
print('# arguments for vcom')
print('quietly set vcom_args "-modelsimini modelsim.ini -explicit -stats=none -work $work -$vhdl"')
print('')
print('# arguments for vlog')
print('quietly set vlog_args "-modelsimini modelsim.ini -stats=none"')
print('')
print('# arguments for vsim')
print('quietly set vsim_lib [join [lmap l $libs {string cat "-L $l"}]]')
print('quietly set vsim_gen [join [lmap g $gens {string cat "-g[lindex $g 0]=[lindex $g 1]"}]]')
print('quietly set vsim_sdf [join [lmap m $sdfs {string cat "-sdf[lindex $m 0] [lindex $m 1]=[lindex $m 2]"}]]')
print('quietly set vsim_tcl "set NumericStdNoWarnings 1; if \[file exists wave.do\] {do wave.do}; run -all; noview .main_pane.source; view wave; wave zoom full"')
print('quietly set vsim_args "$vsim_lib $vsim_gen -t ps -gui -onfinish stop -do \\"$vsim_tcl\\""')
print('')
print('################################################################################')
print('# common section')
print('')
print('# initialise - create modelsim.ini, then create and map user libaries')
print('proc init {} {')
print('  global srcs ')
print('  if {![file exists modelsim.ini]} {vmap -c}')
print('  set srcs_dict [dict create]')
print('  foreach src $srcs {dict set srcs_dict [lindex $src 0] [lindex $src 1]}')
print('  foreach lib [dict keys $srcs_dict] {')
print('    if {![file isdirectory $lib]} {')
print('      vlib $lib')
print('      vmap -modelsimini modelsim.ini $lib $lib')
print('    }')
print('  }')
print('}')
print('')
print('# compile all (skips up to date sources)')
print('proc com {{force ""}} {')
print('  global srcs vcom_args vlog_args')
print('  set compile_needed [expr ! [string equal $force ""]]')
print('  foreach s $srcs {')
print('    set lib [lindex $s 0]')
print('    set src [lindex $s 1]')
print('    set com "$lib/[file tail $src].com"')
print('    if {![file exist $com]} {')
print('      set compile_needed 1')
print('    } else {')
print('      if {[file mtime $src] > [file mtime $com]} {')
print('        set compile_needed 1')
print('      }')
print('    }')
print('    if {$compile_needed} {')
print('      if {[string range [file extension $src] 0 3] == ".vhd"} {')
print('        vcom {*}$vcom_args -work $lib $src')
print('      } else {')
print('        vlog {*}$vlog_args -work $lib $src')
print('      }')
print('      close [open $com w]')
print('    } else {')
print('      puts "skipping compilation of $src"')
print('    }')
print('  }')
print('}')
print('')
print('# simulate specified run (defaults to first run)')
print('proc sim {{r ""}} {')
print('  global runs vsim_args')
print('  if {$r == ""} {set r [lindex [lindex $runs 0] 0]}')
print('  set runs_dict [dict create]')
print('  foreach run $runs {dict set runs_dict [lindex $run 0] [lrange $run 1 3]}')
print('  if {[dict exists $runs_dict $r]} {')
print('    set l [dict get $runs_dict $r]')
print('    set top [lindex $l 0]')
print('    set gen [lindex $l 1]')
print('    set sdf [lindex $l 2]')
print('    set vsim_run_gen [join [lmap g $gen {string cat "-g[lindex $g 0]=[lindex $g 1]"}]]')
print('    set vsim_run_sdf [join [lmap m $sdf {string cat "-sdf[lindex $m 0] [lindex $m 1]=[lindex $m 2]"}]]')
print('    vsim {*}$vsim_args {*}$vsim_run_gen {*}$vsim_run_sdf $top')
print('  } else {')
print('    throw {run not found} {run $s not found}')
print('  }')
print('}')
print('')
print('# resimulate')
print('proc resim {} {')
print('  restart -f; run -all; noview .main_pane.source; view wave')
print('}')
print('')
print('# when this script is executed: initialise and compile all')
print('init')
print('com')
