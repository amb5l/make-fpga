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

# run spec: top[,gen][;sdf] for single run or name:top[,gen][;sdf]
#   [name:]top[,gen][;sdf]
def process_run(run):
    # list of runs, each comprising [name,top,gen,sdf]
    #  where gen = list of tuples (name,value)
    #  sdf = list of triplets (delay,path,file)
    r=[]
    for s in run:
        # get name and top (or default to 'sim')
        l = len(s)
        if ';' in s:
            l = s.index(';') # first semicolon demarks SDF or is part of generic
        if ',' in s[:l]:
            l = s[:l].index(',') # first comma before first semicolon must demark generics
        if ':' in s[:l]:
            name = s[:l].split(':')[0]
            top  = s[:l].split(':')[1]
        else:
            name = 'sim'
            top = s[:l]
        r.append([name,top,[],[]])
        s = s[l:]
        # generic section: ,name=value[,name=value...]
        if s:
            while s[0] == ',':
                s = s[1:]
                n,v = s.split('=')
                sq = False # inside single quotes
                dq = False # inside double quotes
                for i in range(len(v)):
                    if (v[i] == ',' or v[i] == ';') and not sq and not dq:
                        v = v[:i]
                        s = v[i:]
                        break
                    elif s[i] == "'":
                        sq = not sq
                    elif s[i] == '"':
                        dq = not dq
                # ensure double quotes around strings
                if ' ' in v and v[0] != '"':
                    v = '"'+v+'"'
                r[-1][2].append((n,v))
        # SDF section: ;sdfxxx:path=file
        while s and s[0] == ';':
            s = s[1:]
            if ':' not in s:
                error_exit('bad SDF section in run spec:\n  %s' % s)
            delay = s.split(':')[0]
            if delay != 'typ' and delay != 'min' and delay != 'max':
                error_exit('bad SDF delay in run spec: %s' % delay)
            path,file = s[s.index(':')+1:].split('=')
            if ';' in file:
                file = file.split(';')[0]
                s = file[file.index(';'):]
            else:
                s = ''
            r[-1][3].append((delay,path,file))
        # finale
        if s:
            error_exit('unexpected text in SDF section of run spec:\n  %s' % s)
    return r

def process_gen(gen):
    if gen:
        for i in range(len(gen)):
            s = gen[i]
            n,v = s.split('=')
            sq = False # inside single quotes
            dq = False # inside double quotes
            for j in range(len(v)):
                if (v[j] == ',' or v[j] == ';') and not sq and not dq:
                    v = v[:j]
                    s = v[j:]
                    break
                elif s[j] == "'":
                    sq = not sq
                elif s[j] == '"':
                    dq = not dq
            if ' ' in v and v[0] != '"': # ensure double quotes around strings
                v = '"'+v+'"'
            gen[i] = (n,v)
        return gen
    else:
        return []

def process_sdf(sdf):
    if sdf:
        for i in range(len(sdf)):
            s = sdf[i]
            if ':' not in s:
                error_exit('bad SDF mapping: %s' % s)
            delay = s.split(':')[0]
            if delay != 'typ' and delay != 'min' and delay != 'max':
                error_exit('bad SDF delay: %s' % delay)
            path,file = s[s.index(':')+1:].split('=')
            sdf[i] = (delay,path,file)
        return sdf
    else:
        return []

def flatten(ll):
    return [] if ll==None else [e for l in ll for e in l]

def var_vals(l):
    if l:
        if len(l)==1:
            return l[0]
        else:
            return ' \\\n\t'+' \\\n\t'.join(l)
    else:
        return ''

help_run = \
    'A generic assignment is specified as follows:\n' \
    '  name=value\n' \
    'Examples:\n' \
    '  my_int=123\n' \
    '  my_str="abc"\n' \
    '  my_slv="101"\n' \
    '\n' \
    'An SDF mapping is specified as follows:\n' \
    '  delay:path=file\n' \
    'where\n' \
    '  delay = typ, min or max\n' \
    '  unit = path to design unit e.g. /top/u1\n' \
    '  file = path/name of SDF file\n' \
    '\n' \
    'A simulation run is specified as follow:\n' \
    '  [name:]top[,gen][;sdf]\n' \
    'where\n' \
    '  name = unique run name (defaults to sim)\n' \
    '  top  = top design unit\n' \
    '  gen  = run specific generic assignments:\n' \
    '           name=value[,name=value...]\n' \
    '  sdf  = run specific SDF assignments:\n' \
    '           delay:unit=file[;delay=unit=file...]\n' \
    'Examples:\n' \
    ' run1:my_design1\n' \
    ' run2:my_design2,gen1=123,gen2="abc"\n' \
    ' run3:my_design3,gen1=123,gen2="abc";typ:/TOP/UNIT1=unit1.sdf\n' \
    ' run4:my_design4,gen1=123;typ=/TOP/U1=unit1.sdf;min:/TOP/U2=unit2.sdf\n'
