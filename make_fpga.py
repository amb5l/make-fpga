################################################################################
# make_fpga.py
# A part of make-fpga - see https://github.com/amb5l/make-fpga
# This script generates makefiles to build and simulate FPGA designs.
################################################################################

import sys,os,argparse

def error_exit(s):
    sys.exit(sys.argv[0]+': error: '+s)

################################################################################
# parse arguments

parser = argparse.ArgumentParser(
    prog='make_fpga.py',
    description='Create makefiles for FPGA builds and simulations',
    epilog='Run make_fpga.py TOOL -h to see help for TOOL'
   )
parser._positionals.title = 'tools'

subparsers = parser.add_subparsers(help='description')

help_run = \
    'Each simulation RUN is specified as follows:\n' \
    '  [name:]top[,gen]\n' \
    'where\n' \
    '  name = unique run name (defaults to sim)\n' \
    '  top  = top design unit\n' \
    '  gen  = generic assignments (name1=value1,name2=value2...)\n'

#parser_vivado = subparsers.add_parser(
#    'vivado',
#    help='build and simulate FPGAs with AMD/Xilinx Vivado',
#    epilog=help_run,
#    formatter_class=argparse.RawTextHelpFormatter
#   )
#parser_quartus = subparsers.add_parser(
#    'quartus',
#    help='build FPGAs with Intel/Altera Quartus'
#   )
#parser_ghdl = subparsers.add_parser('ghdl',
#    help='simulate with GHDL',
#    epilog=help_run,
#    formatter_class=argparse.RawTextHelpFormatter
#   )
#parser_nvc = subparsers.add_parser('nvc',
#    help='simulate with NVC',
#    epilog=help_run,
#    formatter_class=argparse.RawTextHelpFormatter)
#parser_xsim = subparsers.add_parser(
#    'xsim',
#    help='simulate with AMD/Xilinx XSim',
#    epilog=help_run,
#    formatter_class=argparse.RawTextHelpFormatter
#   )

#-------------------------------------------------------------------------------
# Arguments for Lattice Radiant

parser_radiant = subparsers.add_parser(
    'radiant',
    help='build FPGAs with Lattice Radiant'
   )
parser_radiant.add_argument(
    '--tool',
    choices=['radiant'],
    help=argparse.SUPPRESS,
    default='radiant'
   )
parser_radiant.add_argument(
    '--flow',
    choices=['cmd','ide'],
    help='tool flow (command line or IDE)',
    default='cmd'
   )
parser_radiant.add_argument(
    '--arch',
    required=True,
    help='FPGA architecture e.g. ice40up'
   )
parser_radiant.add_argument(
    '--dev',
    required=True,
    help='FPGA device e.g. iCE40UP5K-SG48I'
   )
parser_radiant.add_argument(
    '--perf',
    help='FPGA performance grade e.g. High-Performance_1.2V',
   )
parser_radiant.add_argument(
    '--freq',
    help='FPGA frequency target for synthesis e.g. 25.0MHz'
   )
parser_radiant.add_argument(
    '--vhdl',
    choices=['2008'],
    help='enable VHDL-2008 support'
   )
parser_radiant.add_argument(
    '--work',
    help='work library (defaults to "work")',
    default='work'
   )
parser_radiant.add_argument(
    '--src',
    required=True,
    nargs='+',
    action='append',
    help='source(s) in compile order (append =LIB to specify library name)'
   )
parser_radiant.add_argument(
    '--ldc',
    nargs='+',
    action='append',
    help='logical (pre-synthesis) design constraints'
   )
parser_radiant.add_argument(
    '--pdc',
    nargs='+',
    action='append',
    help='physical (post-synthesis) design constraints'
   )
parser_radiant.add_argument(
    '--top',
    required=True,
    help='top level design unit'
   )
parser_radiant.add_argument(
    '--gen',
    nargs='+',
    action='append',
    help='generic=value[,generic=value ...]'
   )
parser_radiant.add_argument(
    '-q',
    '--quiet',
    action='store_true',
    help='suppress comments'
   )

#-------------------------------------------------------------------------------
# Arguments for ModelSim/Quest/etc (vsim)

parser_vsim = subparsers.add_parser(
    'vsim',
    help='simulate with ModelSim/Questa/etc',
    epilog=help_run,
    formatter_class=argparse.RawTextHelpFormatter
   )
parser_vsim.add_argument(
    '--tool',
    choices=['vsim'],
    help=argparse.SUPPRESS,
    default='vsim'
   )
parser_vsim.add_argument(
    '--path',
    help='path to tool binaries'
   )
parser_vsim.add_argument(
    '--lib',
    nargs='+',
    action='append',
    help='vendor libraries'
   )
parser_vsim.add_argument(
    '--vhdl',
    choices=['1987','1993','2002','2008'],
    help='VHDL LRM version e.g. 2008 (defaults to 2002)',
    default='2008'
   )
parser_vsim.add_argument(
    '--work',
    help='work library (defaults to "work")',
    default='work'
   )
parser_vsim.add_argument(
    '--src',
    required=True,
    nargs='+',
    action='append',
    help='source(s) in compile order (append =LIB to specify library name)'
   )
parser_vsim.add_argument(
    '--run',
    nargs='+',
    action='append',
    help='simulation run specification(s)'
   )
parser_vsim.add_argument(
    '-q',
    '--quiet',
    action='store_true',
    help='suppress comments'
   )

#-------------------------------------------------------------------------------
# Arguments for Visual Studio Code

parser_vscode  = subparsers.add_parser(
    'vscode',
    help='edit with Visual Studio Code (supports V4P extension)'
   )
parser_vscode.add_argument(
    '--tool',
    choices=['vscode'],
    help=argparse.SUPPRESS,
    default='vscode'
   )
parser_vscode.add_argument(
    '--src',
    required=True,
    nargs='+',
    action='append',
    help='source(s) (append =LIB to specify library name)'
   )
parser_vscode.add_argument(
    '--top',
    action='append',
    help='top level design unit(s)'
   )
parser_vscode.add_argument(
    '-q',
    '--quiet',
    action='store_true',
    help='suppress comments'
   )

#-------------------------------------------------------------------------------

args=parser.parse_args()

def process_src(arg):
    l=[] # list of tuples, each comprising lib and source
    d={} # dict of libraries, each containing all sources
    s=[]
    is_lib=False
    for a in arg:
        for i in a:
            if is_lib:
                if i not in d:
                    d[i]=[]
                l+=[(i,e) for e in s]
                d[i]+=s
                s=[]
                is_lib=False
            elif '=' in i: # src=lib,=lib or =
                if i.split('=')[0]: # src specified
                    s.append(i.split('=')[0])
                if i.split('=')[1]: # lib specified
                    if i.split('=')[1] not in d:
                        d[i.split('=')[1]]=[]
                    l+=[(i.split('=')[1],e) for e in s]
                    d[i.split('=')[1]]+=s
                    s=[]
                else:
                    is_lib=True # defer
            else:
                s.append(i)
    if s:
        if args.work not in d:
            d[args.work]=[]
        l+=[(args.work,e) for e in s]
        d[args.work]+=s
    return l,d

def flatten(ll):
    return None if ll==None else [e for l in ll for e in l]

def var_vals(l):
    if l:
        if len(l)==1:
            return l[0]
        else:
            return ' \\\n\t'+' \\\n\t'.join(l)
    else:
        return ''

#-------------------------------------------------------------------------------

print('# makefile generated by make_fpga.py (see https://github.com/amb5l/make-fpga)')

#-------------------------------------------------------------------------------
# Output for Lattice Radiant

if args.tool=="radiant":
    c,_=process_src(args.src)
    args.pdc=flatten(args.pdc)
    args.ldc=flatten(args.ldc)
    args.gen=flatten(args.gen)
    if not args.quiet:
        print('# for building an FPGA using Lattice Radiant.')
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
    print('\t\t-top $(TOP) \\')
    print('\t\t$(addprefix -hdl_param ,$(subst =,$(comma),$(GEN)))')
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

#-------------------------------------------------------------------------------
# Output for ModelSim/Questa/etc (vsim)

if args.tool=="vsim":
    c,d=process_src(args.src)
    args.lib=flatten(args.lib)
    args.run=flatten(args.run)
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

#-------------------------------------------------------------------------------
# Output for Visual Studio Code

elif args.tool=="vscode":
    _,d=process_src(args.src)
    LIB=list(d)
    if not args.quiet:
        print('# for editing an FPGA/simulation project with Visual Studio Code.')
        print('# Also supports V4P (see https://www.vide-software.at/).')
        print('')
        print('################################################################################')
        print('')
        print('# libraries')
    print('LIB:='+' '.join(d))
    if not args.quiet:
        print('')
        print('# path(s) to source(s) for each library')
    for l,s in d.items():
        print('SRC.'+l+':= \\\n\t'+' \\\n\t'.join(s))
    if not args.quiet:
        print('')
        print('# top level design unit(s)')
    print('TOP:='+' '.join(args.top))
    if not args.quiet:
        print('')
        print('################################################################################')
        print('')
        print('# useful definitions')
    print('space:=$(subst x, ,x)')
    print('comma:=,')
    if not args.quiet:
        print('')
        print('# generate rules and recipes to create all symbolic links')
    print('ifeq ($(OS),Windows_NT)')
    print('define rr_symlink')
    print('$1/$(notdir $2): $2')
    print('\tbash -c "mkdir -p $$(dir $$@)"')
    print('\tbash -c "cmd.exe //C \\\"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\\\""')
    print('endef')
    print('else')
    print('define rr_symlink')
    print('$1/$(notdir $2): $2')
    print('\tmkdir -p $$(dir $$@)')
    print('\tln $$< $$@')
    print('endef')
    print('endif')
    print('$(foreach l,$(LIB),$(foreach s,$(SRC.$l),$(eval $(call rr_symlink,$l,$s))))')
    if not args.quiet:
        print('')
        print('# library directory(s) containing symbolic link(s) to source(s)')
    print('$(foreach l,$(LIB),$(eval $l: $(addprefix $l/,$(notdir $(SRC.$l)))))')
    if not args.quiet:
        print('')
        print('# editing session')
    print('.PHONY: vscode')
    print('vscode: config.v4p $(LIB)')
    print('\tcode .')
    if not args.quiet:
        print('')
        print('# V4P configuration file')
    print('config.v4p: $(LIB)')
    print('\techo "[libraries]" > config.v4p')
    print('\t$(foreach l,$(LIB),$(foreach s,$(SRC.$l),echo "$l/$(notdir $s)=$l" >> config.v4p;))')
    print('\techo "[settings]" >> config.v4p')
    print('\techo "V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(TOP))" >> config.v4p')

#-------------------------------------------------------------------------------
