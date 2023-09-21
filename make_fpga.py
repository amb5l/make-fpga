import sys,os,argparse

def error_exit(s):
    sys.exit(sys.argv[0]+': error: '+s)

################################################################################
# parse arguments

# TODO list required and optional arguments for each tool
#    epilog='Notes:\n'
#    '\n'
#    '2 Each simulation RUN is specified as follows:\n'
#    '    [name:]top[,gen]\n'
#    '  where\n'
#    '    name = unique run name (defaults to sim)\n'
#    '    top  = top design unit\n'
#    '    gen  = generic assignments e.g. name1=value1,name2=value2\n',
#    formatter_class=argparse.RawTextHelpFormatter

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
    '  gen  = optional generic assignments e.g. name1=value1,name2=value2\n'

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
parser_radiant = subparsers.add_parser(
    'radiant',
    help='build FPGAs Lattice Radiant'
   )
#parser_ghdl = subparsers.add_parser('ghdl',
#    help='simulate with GHDL',
#    epilog=help_run,
#    formatter_class=argparse.RawTextHelpFormatter
#   )
#parser_nvc = subparsers.add_parser('nvc',
#    help='simulate with NVC',
#    epilog=help_run,
#    formatter_class=argparse.RawTextHelpFormatter)
parser_vsim = subparsers.add_parser(
    'vsim',
    help='simulate with ModelSim/Questa/etc',
    epilog=help_run,
    formatter_class=argparse.RawTextHelpFormatter
   )
#parser_xsim = subparsers.add_parser(
#    'xsim',
#    help='simulate with AMD/Xilinx XSim',
#    epilog=help_run,
#    formatter_class=argparse.RawTextHelpFormatter
#   )
parser_vscode  = subparsers.add_parser(
    'vscode',
    help='edit with Visual Studio Code (supports V4P extension)'
   )

#-------------------------------------------------------------------------------

parser_radiant.add_argument(
    '--path',
    action='append', # to detect repeats
    help='path to tool binaries'
   )
parser_radiant.add_argument(
    '--flow',
    choices=['cmd','ide'],
    action='append', # to detect repeats
    help='tool flow (command line or IDE)',
    default='cmd'
   )
parser_radiant.add_argument(
    '--arch',
    required=True,
    action='append', # to detect repeats
    help='FPGA architecture e.g. ice40up'
   )
parser_radiant.add_argument(
    '--dev',
    required=True,
    action='append', # to detect repeats
    help='FPGA device e.g. iCE40UP5K-SG48I'
   )
parser_radiant.add_argument(
    '--perf',
    action='append', # to detect repeats
    help='FPGA performance grade e.g. High-Performance_1.2V'
   )
parser_radiant.add_argument(
    '--freq',
    action='append', # to detect repeats
    help='FPGA frequency target for synthesis e.g. 25.0MHz'
   )
parser_radiant.add_argument(
    '--vhdl',
    action='append', # to detect repeats
    help='VHDL LRM version e.g. 2008 (defaults to 1993)',
    default='1993'
   )
parser_radiant.add_argument(
    '--work',
    action='append', # to detect repeats
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
    action='append', # to detect repeats
    help='top level design unit'
   )
parser_radiant.add_argument(
    '-v',
    '--verbose',
    action='store_true',
    help='add verbose comments'
   )

#-------------------------------------------------------------------------------
# vsim

parser_vsim.add_argument(
    '--vhdl',
    action='append', # to detect repeats
    help='VHDL LRM version e.g. 2008 (defaults to 1993)',
    default='1993'
   )
parser_vsim.add_argument(
    '--work',
    action='append', # to detect repeats
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
    '-v',
    '--verbose',
    action='store_true',
    help='add verbose comments'
   )

#-------------------------------------------------------------------------------
# vscode

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
    action='append', # to detect repeats
    help='top level design unit'
   )

#-------------------------------------------------------------------------------

args=parser.parse_args()

################################################################################
# reject repeated arguments, convert from list to simple

#no_repeats=['id','tool','flow','arch','dev','perf','freq','vhdl','work','top']
#v = vars(args)
#print('v=',v)
#for a in no_repeats:
#    if v[a] != None:
#        if isinstance(v[a],list):
#            if len(v[a]) > 1:
#                error_exit('repeated argument: '+a)
#            globals()[a]=v[a][0]
#        else:
#            globals()[a]=v[a]
#    else:
#        globals()[a]=None

################################################################################

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

################################################################################

def outln(s):
    print(s)

outln('# makefile generated by make_fpga.py (see https://github.com/amb5l/make-fpga)')

################################################################################
# FPGA tool: Radiant

if args.tool=='radiant':

    outln('#   flow = '+flow)
    if arch==None:
        error_exit(tool+': arch not specified')
    outln('#   arch = '+arch)
    if dev==None:
        error_exit(tool+': dev not specified')
    outln('#   dev  = '+dev)
    outln('#   perf = '+perf)
    outln('#   freq = '+freq)
    if vhdl != '1993' and vhdl != '2008':
        error_exit(tool+': unsupported VHDL LRM ('+vhdl+')')
    outln('#   vhdl = '+vhdl)
    outln('')
    outln('ifeq (,$(LATTICE_RADIANT))')
    outln('$(error LATTICE_RADIANT is not defined)')
    outln('endif')
    outln('')
    outln('ifeq ($(OS),Windows_NT)')
    outln('LATTICE_RADIANT:=$(shell cygpath -m $(LATTICE_RADIANT))')
    outln('endif')
    outln('FOUNDRY:=$(LATTICE_RADIANT)/ispfpga')

################################################################################
elif args.tool=="vscode":

    _,d=process_src(args.src)
    LIBS=list(d)
    outln('# for editing an FPGA/simulation project with Visual Studio Code.')
    outln('# Also supports V4P (see https://www.vide-software.at/).')
    outln('')
    outln('################################################################################')
    outln('')
    outln('# libraries')
    outln('LIBS:='+' '.join(d))
    outln('')
    outln('# path(s) to source(s) for each library')
    for l,s in d.items():
        outln('SRCS.'+l+':= \\\n\t'+' \\\n\t'.join(s))
    outln('')
    outln('# top level design unit(s)')
    outln('TOP:='+' '.join(args.top))
    outln('')
    outln('################################################################################')
    outln('')
    outln('# generate rules and recipes to create all symbolic links')
    outln('ifeq ($(OS),Windows_NT)')
    outln('define rr_symlink')
    outln('$1/$(notdir $2): $2')
    outln('\tbash -c "mkdir -p $$(dir $$@)"')
    outln('\tbash -c "cmd.exe //C \\\"mklink $$(shell cygpath -w $$@) $$(shell cygpath -w -a $$<)\\\""')
    outln('endef')
    outln('else')
    outln('define rr_symlink')
    outln('$1/$(notdir $2): $2')
    outln('\tmkdir -p $$(dir $$@)')
    outln('\tln $$< $$@')
    outln('endef')
    outln('endif')
    outln('$(foreach l,$(LIBS),$(foreach s,$(SRCS.$l),$(eval $(call rr_symlink,$l,$s))))')
    outln('')
    outln('# library directory(s) containing symbolic link(s) to source(s)')
    outln('$(foreach l,$(LIBS),$(eval $l: $(addprefix $l/,$(notdir $(SRCS.$l)))))')
    outln('')
    outln('# editing session')
    outln('.PHONY: vscode')
    outln('vscode: config.v4p $(LIBS)')
    outln('\tcode .')
    outln('')
    outln('# V4P configuration file')
    outln('space:=$(subst x, ,x)')
    outln('comma:=,')
    outln('config.v4p: $(LIBS)')
    outln('\techo "[libraries]" > config.v4p')
    outln('\t$(foreach l,$(LIBS),$(foreach s,$(SRCS.$l),echo "$l/$(notdir $s)=$l" >> config.v4p;))')
    outln('\techo "[settings]" >> config.v4p')
    outln('\techo "V4p.Settings.Basics.TopLevelEntities=$(subst $(space),$(comma),$(TOP))" >> config.v4p')
    outln('')
    outln('# cleanup')
    outln('.PHONY: clean')
    outln('clean:')
    outln('\tbash -c "rm -rf *."')

################################################################################
