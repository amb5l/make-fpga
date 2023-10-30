################################################################################
# make_vsim.py
# A part of make-fpga - see https://github.com/amb5l/make-fpga
# This script generates makefiles to simulate FPGA designs with ModelSim etc.
################################################################################

import sys,os,argparse
from make_fpga import *

# parse arguments

parser = argparse.ArgumentParser(
    prog='make_vsim.py',
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
    '--dep',
    nargs='+',
    action='append',
    help='other dependancies e.g. data files'
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
parser.add_argument(
    '--min',
    action='store_true',
    help='minimize makefile (suppress comments)'
   )

args=parser.parse_args()
if args.path:
    args.path += '/' if args.path[-1] != '/' else ''
else:
    args.path = ''
c,d=process_src(args.src,args.work)
args.dep=flatten(args.dep)
runs=process_run(flatten(args.run))
args.lib=flatten(args.lib)
args.gen=process_gen(flatten(args.gen))
args.sdf=process_sdf(flatten(args.sdf))

# output

print('# makefile generated by make_vsim.py (see https://github.com/amb5l/make-fpga)')

if not args.min:
    print('# for simulation using ModelSim/Questa/etc')
    print('')
    print('# path to simulator binaries')
    print('VMAP:=%svlib' % args.path)
    print('VLIB:=%svlib' % args.path)
    print('VCOM:=%svcom' % args.path)
    print('VLOG:=%svlog' % args.path)
    print('VSIM:=%svsim' % args.path)
    print('')
    print('################################################################################')
    print('# simulation specific definitions')
    print('')
    print('# libraries to compile source into')
print('LIB:='+' '.join(d))
if not args.min:
    print('')
    print('# sources in compilation order (source=library)')
print('SRC:='+var_vals([s+'='+l for l,s in c]))
if not args.min:
    print('')
    print('# other simulation prerequisites (e.g. data files)')
print('DEP:='+var_vals(args.dep))
if not args.min:
    print('')
    print('# simulation runs (top plus any run specific generic/SDF assignments)')
print('RUNS:='+' '.join([r[0] for r in runs]))
for r in runs:
    s = 'RUN.'+r[0]+':='+r[1]
    if r[2]:
        s += ' '+' '.join(['-g'+g+'='+v for g,v in r[2]])
    if r[3]:        
        s += ' '+' '.join(['-sdf'+t+' '+p+'='+f for t,p,f in r[3]])
    print(s)
if not args.min:
    print('')
    print('# generic assignments (applied to all simulation runs)')
print('GEN:='+var_vals(list(map(lambda e: '-g'+e[0]+'='+e[1],args.gen))))
if not args.min:
    print('')
    print('# SDF mappings (applied to all simulation runs)')
print('SDF:='+var_vals(list(map(lambda e: '-sdf'+e,args.sdf))))
if not args.min:
    print('')
    print('# compilation and simulation options')
print('VCOM_OPTS:=-'+args.vhdl+' -explicit -stats=none')
print('VLOG_OPTS:=-stats=none')
print('VSIM_TCL:=set NumericStdNoWarnings 1; onfinish exit; run -all; exit')
print('VSIM_OPTS:=-t ps -c -onfinish stop -do "$(VSIM_TCL)"')
if not args.min:
    print('')
    print('# precompiled libraries')
print('VSIM_LIB:='+var_vals(args.lib))
if not args.min:
    print('')
    print('################################################################################')
    print('')
    print('# default goal')
print('all: vsim')
if not args.min:
    print('')
    print('# useful definitions')
print('comma:=,')
print('rest=$(wordlist 2,$(words $1),$1)')
print('chop=$(wordlist 1,$(words $(call rest,$1)),$1)')
print('src_dep=$1,$2')
print('pairmap=$(and $(strip $2),$(strip $3),$(call $1,$(firstword $2),$(firstword $3)) $(call pairmap,$1,$(call rest,$2),$(call rest,$3)))')
if not args.min:
    print('')
    print('# create modelsim.ini')
print('modelsim.ini:')
print('\t$(VMAP) -c')
if not args.min:
    print('')
    print('# generate rule(s) and recipe(s) to create library directory(s)')
print('define rr_libdir')
print('$1: | modelsim.ini')
print('\t$(VLIB) $$@')
print('\t$(VMAP) -modelsimini modelsim.ini $$@ $$@')
print('endef')
print('$(foreach l,$(LIB),$(eval $(call rr_libdir,$l)))')
if not args.min:
    print('')
    print('# compilation dependencies enforce compilation order')
print('dep:=$(firstword $(SRC)), $(if $(word 2,$(SRC)),$(call pairmap,src_dep,$(call rest,$(SRC)),$(call chop,$(SRC))),)')
if not args.min:
    print('')
    print('# generate rule(s) and recipe(s) to compile source(s)')
print('define rr_compile')
print('$1/$(notdir $2).com: $2 $3 $(DEP) | $1')
print('\t$(if $(filter .vhd,$(suffix $2)),$(VCOM) $(VCOM_OPTS),$(VLOG) $(VLOG_OPTS)) \\')
print('\t\t-modelsimini modelsim.ini -work $1 $$<')
print('\ttouch $$@')
print('endef')
print('$(foreach d,$(dep),$(eval $(call rr_compile, \\')
print('$(word 2,$(subst =, ,$(word 1,$(subst $(comma), ,$d)))), \\')
print('$(word 1,$(subst =, ,$(word 1,$(subst $(comma), ,$d)))), \\')
print('$(addsuffix .com,$(addprefix $(word 2,$(subst =, ,$(word 2,$(subst $(comma), ,$d))))/,$(notdir $(word 1,$(subst =, ,$(word 2,$(subst $(comma), ,$d))))))) \\')
print(')))')
if not args.min:
    print('')
    print('# generate rule(s) and recipe(s) to run simulation(s)')
print('define rr_run')
print('$1: $(word 2,$(subst =, ,$(lastword $(SRC))))/$(notdir $(word 1,$(subst =, ,$(lastword $(SRC))))).com')
print('\t@bash -c \'echo -e "\\033[0;32mRUN: $1 ($(word 1,$(RUN.$1)))  start at $$$$(date +%T.%2N)\\033[0m"\'')
print('\t$(VSIM) -modelsimini modelsim.ini $(addprefix -L ,$(VSIM_LIB)) $(VSIM_OPTS) $(GEN) $(SDF) $(RUN.$1)')
print('\t@bash -c \'echo -e "\\033[0;31mRUN: $1 ($(word 1,$2))    end at $$$$(date +%T.%2N)\\033[0m"\'')
print('vsim:: $1')
print('endef')
print('$(foreach r,$(RUNS),$(eval $(call rr_run,$r)))')
