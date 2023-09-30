################################################################################
# make_vsim.py
# A part of make-fpga - see https://github.com/amb5l/make-fpga
# This script generates makefiles for use with GNU make to
# simulate FPGA designs with ModelSim/Questa/etc.
################################################################################

import sys,os,argparse
from make_fpga import *

# parse arguments

parser = argparse.ArgumentParser(
    prog='make_vsim.py',
    description='Create makefiles for simulating FPGA designs with ModelSim/Questa/etc',
    epilog=help_run
   )
parser.add_argument(
    '--path',
    help='path to tool binaries'
   )
parser.add_argument(
    '--lib',
    nargs='+',
    action='append',
    help='vendor libraries'
   )
parser.add_argument(
    '--vhdl',
    choices=['1987','1993','2002','2008'],
    help='VHDL LRM version e.g. 2008 (defaults to 2002)',
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
    nargs='+',
    action='append',
    help='simulation run specification(s)'
   )
parser.add_argument(
    '-q',
    '--quiet',
    action='store_true',
    help='suppress comments'
   )

args=parser.parse_args()
c,d=process_src(args.src,args.work)
args.lib=flatten(args.lib)
args.run=flatten(args.run)

# output

print('# makefile generated by make_fpga.py (see https://github.com/amb5l/make-fpga)')

if not args.quiet:
    print('# for simulation using ModelSim/Questa/etc')
    print('')
    print('################################################################################')
    print('# simulation specific definitions')
    print('')
    print('# libraries to compile source into')
print('LIB:='+' '.join(d))
if not args.quiet:
    print('')
    print('# sources in compilation order (source=library)')
print('SRC:='+var_vals([s+'='+l for l,s in c]))
if not args.quiet:
    print('')
    print('# simulation runs')
print('RUN:='+var_vals(args.run))
if not args.quiet:
    print('')
    print('# compilation and simulation options')
print('VCOM_OPTS:=-'+args.vhdl+' -explicit -stats=none')
print('VLOG_OPTS:=-stats=none')
print('VSIM_TCL:=set NumericStdNoWarnings 1; onfinish exit; run -all; exit')
print('VSIM_OPTS:=-t ps -c -onfinish stop -do "$(VSIM_TCL)"')
if not args.quiet:
    print('')
    print('# simulation vendor libraries')
print('VSIM_LIB:='+var_vals(args.lib))
if not args.quiet:
    print('')
    print('################################################################################')
    print('')
    print('# default goal')
print('all: vsim')
if not args.quiet:
    print('')
    print('# default name for single run')
print('RUN:=$(if $(word 2,$(RUN)),$(RUN),$(if $(filter :,$(RUN)),$(RUN),sim:$(RUN)))')
if not args.quiet:
    print('')
    print('# useful definitions')
print('comma:=,')
print('rest=$(wordlist 2,$(words $1),$1)')
print('chop=$(wordlist 1,$(words $(call rest,$1)),$1)')
print('src_dep=$1,$2')
print('pairmap=$(and $(strip $2),$(strip $3),$(call $1,$(firstword $2),$(firstword $3)) $(call pairmap,$1,$(call rest,$2),$(call rest,$3)))')
if not args.quiet:
    print('')
    print('# create modelsim.ini')
print('modelsim.ini:')
print('\tvmap -c')
if not args.quiet:
    print('')
    print('# generate rule(s) and recipe(s) to create library directory(s)')
print('define rr_libdir')
print('$1: | modelsim.ini')
print('\tvlib $$@')
print('\tvmap -modelsimini modelsim.ini $$@ $$@')
print('endef')
print('$(foreach l,$(LIB),$(eval $(call rr_libdir,$l)))')
if not args.quiet:
    print('')
    print('# compilation dependencies enforce compilation order')
print('dep:=$(firstword $(SRC)), $(if $(word 2,$(SRC)),$(call pairmap,src_dep,$(call rest,$(SRC)),$(call chop,$(SRC))),)')
if not args.quiet:
    print('')
    print('# generate rule(s) and recipe(s) to compile source(s)')
print('define rr_compile')
print('$1/$(notdir $2).com: $2 $3 | $1')
print('\t$(if $(filter .vhd,$(suffix $2)),vcom $(VCOM_OPTS),vlog $(VLOG_OPTS)) \\')
print('\t\t-modelsimini modelsim.ini -work $1 $$<')
print('\ttouch $$@')
print('endef')
print('$(foreach d,$(dep),$(eval $(call rr_compile, \\')
print('$(word 2,$(subst =, ,$(word 1,$(subst $(comma), ,$d)))), \\')
print('$(word 1,$(subst =, ,$(word 1,$(subst $(comma), ,$d)))), \\')
print('$(addsuffix .com,$(addprefix $(word 2,$(subst =, ,$(word 2,$(subst $(comma), ,$d))))/,$(notdir $(word 1,$(subst =, ,$(word 2,$(subst $(comma), ,$d))))))) \\')
print(')))')
if not args.quiet:
    print('')
    print('# generate rule(s) and recipe(s) to run simulation(s)')
print('define rr_run')
print('$1: $(word 2,$(subst =, ,$(lastword $(SRC))))/$(notdir $(word 1,$(subst =, ,$(lastword $(SRC))))).com')
print('\t@bash -c \'echo -e "\\033[0;32mRUN: $1 ($2)  start at $$$$(date +%T.%2N)\\033[0m"\'')
print('\tvsim -modelsimini modelsim.ini \\')
print('\t\t$(addprefix -L ,$(VSIM_LIB)) $(VSIM_OPTS) $2 $(addprefix -g ,$3)')
print('\t@bash -c \'echo -e "\\033[0;31mRUN: $1 ($2)    end at $$$$(date +%T.%2N)\\033[0m"\'')
print('vsim:: $1')
print('endef')
print('$(foreach r,$(RUN),$(eval $(call rr_run, \\')
print('$(word 1,$(subst :, ,$r)), \\')
print('$(word 1,$(subst $(comma), ,$(word 2,$(subst :, ,$r)))), \\')
print('$(call rest,$(subst $(comma), ,$(word 2,$(subst :, ,$r)))) \\')
print(')))')
