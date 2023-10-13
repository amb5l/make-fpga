################################################################################
# make_radiant.py
# A part of make-fpga - see https://github.com/amb5l/make-fpga
# This script generates makefiles for use with GNU make to
# build FPGA designs with Lattice Radiant.
################################################################################

import sys,os,argparse
from make_fpga import *

# parse arguments

parser = argparse.ArgumentParser(
    prog='make_radiant.py',
    description='Create makefiles for building FPGA designs with Lattice Radiant',
   )
parser.add_argument(
    '--flow',
    choices=['cmd','ide'],
    help='tool flow (command line or IDE)',
    default='cmd'
   )
parser.add_argument(
    '--arch',
    required=True,
    help='FPGA architecture e.g. ice40up'
   )
parser.add_argument(
    '--dev',
    required=True,
    help='FPGA device e.g. iCE40UP5K-SG48I'
   )
parser.add_argument(
    '--perf',
    help='FPGA performance grade e.g. High-Performance_1.2V',
   )
parser.add_argument(
    '--freq',
    help='FPGA frequency target for synthesis e.g. 25.0MHz'
   )
parser.add_argument(
    '--use_io_reg',
    choices=['0','1','auto'],
    default='auto',
    help='control I/O register packing'
   )
parser.add_argument(
    '--vhdl',
    choices=['1993','2008'],
    default='2008',
    help='enable VHDL-2008 support'
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
    '--ldc',
    nargs='+',
    action='append',
    help='logical (pre-synthesis) design constraints'
   )
parser.add_argument(
    '--pdc',
    nargs='+',
    action='append',
    help='physical (post-synthesis) design constraints'
   )
parser.add_argument(
    '--top',
    required=True,
    help='top level design unit'
   )
parser.add_argument(
    '--gen',
    nargs='+',
    action='append',
    help='generic=value[,generic=value ...]'
   )
parser.add_argument(
    '-q',
    '--quiet',
    action='store_true',
    help='suppress comments'
   )

args=parser.parse_args()
c,_=process_src(args.src,args.work)
args.pdc=flatten(args.pdc)
args.ldc=flatten(args.ldc)
args.gen=flatten(args.gen)

# output

print('# makefile generated by make_fpga.py (see https://github.com/amb5l/make-fpga)')
if not args.quiet:
    print('# for building an FPGA design using Lattice Radiant.')
    print('')
print('ifndef FOUNDRY')
print('$(error Lattice FOUNDRY environment variable is not defined)')
print('endif')
if not args.quiet:
    print('')
    print('################################################################################')
    print('# design specific definitions')
    print('')
    print('# FPGA')
print('ARCH:='+args.arch)
print('DEV:='+args.dev)
print('PERF:='+(args.perf if args.perf else ''))
print('FREQ:='+(args.freq if args.freq else ''))
if not args.quiet:
    print('')
    print('# sources in compilation order (source=library)')
print('VHDL:='+('2008' if args.vhdl else ''))
print('SRC:='+var_vals([s+'='+l for l,s in c]))
if not args.quiet:
    print('')
    print('# logical (pre-synthesis) constraints')
print('LDC:='+var_vals(args.ldc))
if not args.quiet:
    print('')
    print('# physical (post-synthesis) constraints')
print('PDC:='+var_vals(args.pdc))
if not args.quiet:
    print('')
    print('# top level design unit')
print('TOP:='+args.top)
if not args.quiet:
    print('')
    print('# top level VHDL generics / Verilog parameters')
print('GEN:='+var_vals(args.gen))
if not args.quiet:
    print('')
    print('################################################################################')
    print('')
    print('# useful definitions')
print('comma:=,')
if not args.quiet:
    print('')
    print('# Synthesis (compile structural Verilog netlist from HDL source)')
print('comma:=,')
print('$(TOP)_synth.vm: $(foreach p,$(SRC),$(word 1,$(subst =, ,$p))) $(LDC)')
print('\tsynthesis \\')
print('\t\t-output_hdl $@ \\')
print('\t\t-a $(ARCH) \\')
print('\t\t-p $(word 1,$(subst -, ,$(DEV))) \\')
print('\t\t-t $(shell echo $(DEV)| grep -Po "(?<=-)(.+\d+)") \\')
print('\t\t$(addprefix -sp ,$(PERF)) \\')
print('\t\t$(addprefix -frequency ,$(FREQ)) \\')
print('\t\t$(addprefix -vh,$(VHDL)) \\')
print('\t\t$(foreach p,$(SRC),\\\n\t\t -lib $(word 2,$(subst =, ,$p)) \\\n\t\t -$(if $(filter .vhd,$(suffix $(word 1,$(subst =, ,$p)))),vhd,ver) \\\n\t\t  $(word 1,$(subst =, ,$p)) \\\n\t\t) \\')
print('\t\t$(addprefix -sdc ,$(LDC)) \\')
print('\t\t-use_io_reg %s \\' % args.use_io_reg)
print('\t\t-top $(TOP) \\')
print('\t\t$(addprefix -hdl_param ,$(subst =,$(comma),$(GEN))) \\')
print('\t\t-logfile $(basename $@).log')
if not args.quiet:
    print('')
    print('# Post Synthesis (combine .vm and IP into Unified Database)')
print('$(TOP)_postsyn.udb: $(TOP)_synth.vm $(LDC)')
print('\tpostsyn \\')
print('\t\t-w \\')
print('\t\t-a $(ARCH) \\')
print('\t\t-p $(word 1,$(subst -, ,$(DEV))) \\')
print('\t\t-t $(shell echo $(DEV)| grep -Po "(?<=-)(.+\d+)") \\')
print('\t\t$(addprefix -sp ,$(PERF)) \\')
print('\t\t$(addprefix -ldc ,$(LDC)) \\')
print('\t\t-o $@ \\')
print('\t\t-top \\')
print('\t\t$(notdir $<)')
if not args.quiet:
    print('')
    print('# Map (convert generic logic to device specific resources)')
print('$(TOP)_map.udb: $(TOP)_postsyn.udb $(PDC)')
print('\tmap $^ -o $@ -mp $(basename $@).mrp -xref_sig -xref_sym')
if not args.quiet:
    print('')
    print('# Place and Route')
print('$(TOP)_par.udb: $(TOP)_map.udb $(PDC)')
print('\tpar -w -n 1 -t 1 -stopzero $< $@')
if not args.quiet:
    print('')
    print('# Generate SPI programming file')
print('$(TOP).bin: $(TOP)_par.udb')
print('\tbitgen -w $< $@')
if not args.quiet:
    print('')
    print('# Generate NVCM programming file')
print('$(TOP).nvcm: $(TOP)_par.udb')
print('\tbitgen -w -nvcm -nvcmsecurity $< $@')
if not args.quiet:
    print('')
    print('# Generate Verilog netlist and structured delay file for timing simulation')
print('$(TOP).vo $(TOP).sdf: $(TOP)_par.udb')
print('\tbackanno -w -neg -x -o $(TOP).vo -d $(TOP).sdf $<')
