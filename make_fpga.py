import sys,argparse

fpga_tools=["vivado","quartus","radiant"]
sim_tools=["ghdl","nvc","vsim","xsim"]
tools=fpga_tools+sim_tools

#		--id   $(dut_id) \
#		--tool radiant \
#		--flow cmd \
#		--arch $(fpga_arch) \
#		--dev  $(fpga_dev) \
#		--perf $(fpga_perf) \
#		--freq $(fpga_freq) \
#		--vhdl 2008 \
#		--src  $(dut_src) \
#		--pdc  $(dut_pdc) \
#		--top  $(dut)
#		> sub.mak
#	$(MAKE_FPGA) \
#		--id   $(sim_id) \
#		--tool vsim \
#		--path  $(LATTICE_RADIANT)/modeltech/win32loem \
#		--src  dut_behavioural = $(dut_src) \
#		--src  dut_timing = .radiant/$(dut).vo \
#		--src  testbench = src2 \
#		--run  $(cfg)_$(MODE) \

def error_exit(s):
    sys.exit(sys.argv[0]+": error: "+s)

################################################################################
# parse arguments

parser = argparse.ArgumentParser(
    prog="make_fpga.py",
    description="Creates makefiles for FPGA builds and simulations",
    epilog=
    "Notes:\r\n"
    "\r\n"
    "1 Sources should be listed in compile order.\r\n"
    "\r\n"
    "2 A simulation run is specified as follows:\r\n"
    "    NAME:TOP[,GEN]\r\n"
    "  where NAME is a unique run name, TOP is the top design unit, and \r\n"
    "  GEN is an optional comma separated list of generic assignments.\r\n"
    "  For the simple case of a single simulation run, NAME: may be omitted.\r\n"
    "  Examples:\r\n"
    '    testbench_top\r\n'
    '    testbench_top,my_generic=123\r\n'
    '    run1:tb1 run2:tb2\r\n'
    '    run1:tb1,a=123,b="abc" run2:tb2,a=456,b="def"\r\n',
    formatter_class=argparse.RawTextHelpFormatter
    )

parser.add_argument(
    "--id",
    action="append", # to detect repeats
    required=True,
    help="identifier (used as subdirectory name and variable prefix)"
    )
parser.add_argument(
    "--tool",
    choices=tools,
    action="append", # to detect repeats
    required=True,
    help="tool name"
    )
parser.add_argument(
    "--path",
    action="append", # to detect repeats
    help="tool path"
    )
parser.add_argument(
    "--flow",
    action="append", # to detect repeats
    help="tool flow (e.g. cmd or ide)"
    )
parser.add_argument(
    "--arch",
    action="append", # to detect repeats
    help="FPGA architecture (Radiant only)"
    )
parser.add_argument(
    "--dev",
    action="append", # to detect repeats
    help="FPGA device"
    )
parser.add_argument(
    "--perf",
    action="append", # to detect repeats
    help="FPGA performance grade (Radiant only)"
    )
parser.add_argument(
    "--freq",
    action="append", # to detect repeats
    help="FPGA frequency target for synthesis (Radiant only)"
    )
parser.add_argument(
    "--vhdl",
    action="append", # to detect repeats
    help="VHDL LRM version e.g. 2008 (defaults to 1993)",
    default="1993"
    )
parser.add_argument(
    "--work",
    action="append", # to detect repeats
    help="work library (defaults to work)",
    default="work"
    )
parser.add_argument(
    "--src",
    nargs="+",
    action="append",
    required=True,
    help="source(s) (append =LIB to specify library name)"
    )
parser.add_argument(
    "--sdc",
    nargs="+",
    action="append",
    help="synthesis (logical) design constraints"
    )
parser.add_argument(
    "--pdc",
    nargs="+",
    action="append",
    help="implementation (physical) design constraints"
    )
parser.add_argument(
    "--top",
    action="append", # to detect repeats
    required=True,
    help="top level design unit"
    )
parser.add_argument(
    "--run",
    nargs="+",
    action="append",
    help="simulation run(s)"
    )
parser.add_argument(
    "-v",
    "--verbose",
    action="store_true",
    help="add verbose comments"
    )

args=parser.parse_args()

################################################################################
# reject repeated arguments, convert from list to simple

no_repeats=["id","tool","flow","arch","dev","perf","freq","vhdl","work","top"]
v = vars(args)
print("v=",v)
for a in no_repeats:
    if v[a] != None:
        if isinstance(v[a],list):
            if len(v[a]) > 1:
                error_exit("repeated argument: "+a)
            globals()[a]=v[a][0]
        else:
            globals()[a]=v[a]
    else:
        globals()[a]=None

################################################################################
# process args.src into lib_src

# TODO record compile order

compile_order=[] # list of tuples, each comprising lib and source
lib_src={} # dict of libs, each containing all sources

src=[]
is_lib=False
for l in args.src:
    for s in l:
        if is_lib:
            if s not in lib_src:
                lib_src[s]=[]
            compile_order+=[(s,e) for e in src]
            lib_src[s]+=src
            src=[]
            is_lib=False
        elif "=" in s: # s=l,=l or =
            if s.split("=")[0]: # src specified
                src.append(s.split("=")[0])
            if s.split("=")[1]: # lib specified
                if s.split("=")[1] not in lib_src:
                    lib_src[s.split("=")[1]]=[]
                compile_order+=[(s.split("=")[1],e) for e in src]
                lib_src[s.split("=")[1]]+=src
                src=[]
            else:
                is_lib=True # defer
        else:
            src.append(s)
if src:
    if work not in lib_src:
        lib_src[work]=[]
    compile_order+=[(work,e) for e in src]
    lib_src[work]+=src

# detect empty libraries
for key,value in lib_src.items():
    if not value:
        error_exit("empty library: "+key)

################################################################################

def outln(s):
    print(s)

print("compile_order =",compile_order)

outln( "# make-fpga makefile generated by make_fpga.py" )
outln( "#   - see https://github.com/amb5l/make-fpga" )
outln( "# options:" )
outln( "#   id   = "+id )
outln( "#   tool = "+tool )
for lib,src in lib_src.items():
    outln( "# sources for library '%s':" % lib )
    for s in src:
        outln( "#   %s" % s )
outln( "" )

################################################################################
# FPGA tool: Radiant

if tool=="radiant":

    if flow==None:
        flow = "cmd"
    if flow != "cmd" and flow != "ide":
        error_exit(tool+": unsupported flow ("+flow+")")
    outln( "#   flow = "+flow )
    if arch==None:
        error_exit(tool+": arch not specified")
    outln( "#   arch = "+arch )
    if dev==None:
        error_exit(tool+": dev not specified")
    outln( "#   dev  = "+dev )
    outln( "#   perf = "+perf )
    outln( "#   freq = "+freq )
    if vhdl != "1993" and vhdl != "2008":
        error_exit(tool+": unsupported VHDL LRM ("+vhdl+")")
    outln( "#   vhdl = "+vhdl )

#		--src  $(dut_src) \
#		--pdc  $(dut_pdc) \
#		--top  $(dut)



#
#outln( "" )
#outln( "ifeq (,$(LATTICE_RADIANT))" )
#outln( "$(error LATTICE_RADIANT is not defined)" )
#outln( "endif" )
#outln( "" )
#
#ifeq ($(OS),Windows_NT)
#LATTICE_RADIANT:=$(shell cygpath -m $(LATTICE_RADIANT))
#endif
#FOUNDRY:=$(LATTICE_RADIANT)/ispfpga