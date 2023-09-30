################################################################################
# make_fpga.py
# A part of make-fpga - see https://github.com/amb5l/make-fpga
# Shared functions.
################################################################################

import sys,os,argparse

def error_exit(s):
    sys.exit(sys.argv[0]+': error: '+s)

def process_src(src,work):
    l=[] # list of tuples, each comprising lib and source
    d={} # dict of libraries, each containing all sources
    s=[]
    is_lib=False
    for a in src:
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
        if work not in d:
            d[work]=[]
        l+=[(work,e) for e in s]
        d[work]+=s
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

help_run = \
    'Each simulation RUN is specified as follows:\n' \
    '  [name:]top[,gen]\n' \
    'where\n' \
    '  name = unique run name (defaults to sim)\n' \
    '  top  = top design unit\n' \
    '  gen  = generic assignments (name1=value1,name2=value2...)\n'
