#!/usr/bin/env python3
"""
generate_cuest_fortran.py
=========================

Regenerate the Fortran interface module `cuest.f90` from the cuEST C headers.

The `cuest` API is highly regular (129 functions all returning cuestStatus_t,
67 opaque `void*` handle types, 83 enums, 2 structs), so the Fortran binding is
produced mechanically from the headers rather than maintained by hand.  Re-run
this whenever the headers change (e.g. a new cuEST release):

    python3 generate_cuest_fortran.py                 # auto-detects ../include
    python3 generate_cuest_fortran.py /path/to/include
    python3 generate_cuest_fortran.py /path/to/include -o cuest.f90

Then rebuild:  gfortran -c cuest.f90

Type mapping (see README.md for the rationale):
    cuestStatus_t (return)          -> INTEGER(c_int) FUNCTION result
    <opaque> handle  in-by-value    -> TYPE(c_ptr), VALUE
    <opaque> handle* out            -> TYPE(c_ptr), INTENT(OUT)          (C void**)
    const <opaque>*  (handle array) -> TYPE(c_ptr), DIMENSION(*), INTENT(IN)
    double* / const double*         -> TYPE(c_ptr), VALUE  (GPU device buffers)
    void* / const void*             -> TYPE(c_ptr), VALUE
    const uint64_t* / uint32_t*     -> INTEGER(c_int64_t/32_t), DIMENSION(*), INTENT(IN)
    uint32_t* (scalar out)          -> INTEGER(c_int32_t), INTENT(OUT)
    <enum>* (scalar out)            -> INTEGER(c_int), INTENT(OUT)
    double / uintNN_t / int / enum  -> REAL(c_double) / INTEGER(...) , VALUE
    cuestWorkspace(Descriptor)_t*   -> TYPE(...) interoperable derived type
"""
import re, glob, os, sys, argparse

HERE = os.path.dirname(os.path.abspath(__file__))

ap = argparse.ArgumentParser(description="Generate cuest.f90 from the cuEST C headers.")
ap.add_argument("include", nargs="?", default=os.path.join(HERE, "..", "include"),
                help="path to the cuEST include/ directory (default: ../include)")
ap.add_argument("-o", "--output", default=os.path.join(HERE, "cuest.f90"),
                help="output Fortran file (default: ./cuest.f90)")
args = ap.parse_args()

INC = os.path.abspath(args.include)
if not os.path.exists(os.path.join(INC, "cuest.h")):
    sys.exit(f"error: {INC}/cuest.h not found -- pass the cuEST include/ dir")

def strip_comments(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'//[^\n]*', '', s)
    return s

# ---- include order from cuest.h (for a logical layout) --------------------
top = open(os.path.join(INC, "cuest.h")).read()
order = re.findall(r'#include\s+"(cuest/[^"]+)"', top)
type_headers  = [h for h in order if "/types/" in h]
other_headers = [h for h in order if "/types/" not in h]
all_headers   = type_headers + other_headers

# ---- collect opaque (void*) typedef names ---------------------------------
OPAQUE = set()
for f in glob.glob(os.path.join(INC, "cuest/**/*.h"), recursive=True):
    for m in re.finditer(r'typedef\s+void\s*\*\s*(cuest\w+_t)\s*;', open(f).read()):
        OPAQUE.add(m.group(1))

# ---- collect enum type names and their constants --------------------------
ENUM_TYPES = set()
enum_defs = []            # (type_name, [(const, value)], header)
for h in all_headers:
    path = os.path.join(INC, h)
    if not os.path.exists(path):
        continue
    s = strip_comments(open(path).read())
    for body, tname in re.findall(r'enum\s*\{(.*?)\}\s*(cuest\w+_t)\s*;', s, re.S):
        ENUM_TYPES.add(tname)
        consts, counter = [], 0
        for item in body.split(','):
            item = item.strip()
            if not item:
                continue
            m = re.match(r'([A-Za-z_]\w*)\s*(?:=\s*([^,]+))?$', item)
            name, val = m.group(1), m.group(2)
            if val is not None:
                counter = int(val.strip(), 0)
            consts.append((name, counter))
            counter += 1
        enum_defs.append((tname, consts, h))

# ---- version macros -------------------------------------------------------
vmacros = dict(re.findall(r'#define\s+(CUEST_VER_\w+)\s+(\d+)', top))

# ---- collect function prototypes in include order -------------------------
funcs = []                # (name, [(sig, argname)], header)
for h in other_headers:
    path = os.path.join(INC, h)
    if not os.path.exists(path):
        continue
    s = strip_comments(open(path).read())
    for name, argstr in re.findall(r'cuestStatus_t\s+(cuest\w+)\s*\((.*?)\)\s*;', s, re.S):
        argstr = re.sub(r'\s+', ' ', argstr).strip()
        arglist = []
        if argstr and argstr != 'void':
            for a in argstr.split(','):
                a = a.strip()
                nm = re.search(r'([A-Za-z_]\w*)\s*$', a).group(1)
                sig = a[:a.rfind(nm)].strip()
                arglist.append((sig, nm))
        funcs.append((name, arglist, h))

# ---- argument type mapping ------------------------------------------------
def parse_sig(sig):
    is_const = 'const' in sig
    nstars   = sig.count('*')
    base     = re.sub(r'\bconst\b', '', sig).replace('*', '').strip()
    return is_const, nstars, base

def map_arg(sig, name):
    is_const, nstars, base = parse_sig(sig)
    if base == 'cuestWorkspace_t':
        return f'type(cuestWorkspace_t) :: {name}'
    if base == 'cuestWorkspaceDescriptor_t':
        intent = 'intent(in)' if is_const else 'intent(out)'
        return f'type(cuestWorkspaceDescriptor_t), {intent} :: {name}'
    if base in OPAQUE:
        if nstars == 0:
            return f'type(c_ptr), value :: {name}'
        if is_const:                                    # array of input handles
            return f'type(c_ptr), dimension(*), intent(in) :: {name}'
        return f'type(c_ptr), intent(out) :: {name}'    # output handle (void**)
    if base == 'void':
        if nstars >= 2:
            return f'type(c_ptr), intent(out) :: {name}'
        return f'type(c_ptr), value :: {name}'
    if base == 'double':
        if nstars >= 1:
            return f'type(c_ptr), value :: {name}'       # device/host data buffer
        return f'real(c_double), value :: {name}'
    if base == 'uint64_t':
        if nstars >= 1:
            return f'integer(c_int64_t), dimension(*), intent(in) :: {name}'
        return f'integer(c_int64_t), value :: {name}'
    if base == 'uint32_t':
        if nstars == 0:
            return f'integer(c_int32_t), value :: {name}'
        if is_const:
            return f'integer(c_int32_t), dimension(*), intent(in) :: {name}'
        return f'integer(c_int32_t), intent(out) :: {name}'   # scalar out (version)
    if base == 'int32_t':
        return f'integer(c_int32_t), value :: {name}'
    if base == 'int':
        return f'integer(c_int), value :: {name}'
    if base == 'size_t':
        return f'integer(c_size_t), value :: {name}'
    if base in ENUM_TYPES:
        if nstars == 0:
            return f'integer(c_int), value :: {name}'
        return f'integer(c_int), intent(out) :: {name}'       # enum scalar out
    raise SystemExit(f"UNMAPPED ARG: sig='{sig}' name='{name}' base='{base}'")

# ---- shorten identifiers over Fortran's 63-char limit ---------------------
def fort_name(n):
    if len(n) <= 63:
        return n, None
    short = n.replace('PARAMETERS', 'PARAM')
    if len(short) > 63:
        sys.exit(f"identifier still too long after shortening: {short}")
    return short, n

# ---- emit -----------------------------------------------------------------
out, w = [], None
lines = []
def w(x): lines.append(x)

ver = (vmacros.get('CUEST_VER_MAJOR', '0'),
       vmacros.get('CUEST_VER_MINOR', '2'),
       vmacros.get('CUEST_VER_PATCH', '0'))

w("! ============================================================================")
w("!  cuest.f90 -- Fortran 2008 iso_c_binding interface to NVIDIA cuEST")
w("!")
w("!  GENERATED FILE -- do not edit by hand.")
w("!  Regenerate with:  python3 generate_cuest_fortran.py")
w("!  Source: the cuEST C headers (include/cuest.h, v%s.%s.%s)." % ver)
w("!")
w("!  Conventions")
w("!  -----------")
w("!  * Every cuEST function returns cuestStatus_t; here each is an")
w("!    INTEGER(c_int) FUNCTION whose result is the status code.")
w("!  * All opaque handles (cuestHandle_t, plans, bases, parameter and results")
w("!    objects, ...) are C  void*  and map to TYPE(c_ptr).")
w("!      - handle passed IN  -> TYPE(c_ptr), VALUE")
w("!      - handle returned   -> TYPE(c_ptr), INTENT(OUT)   (C void**)")
w("!  * Bulk numeric buffers (double*, e.g. matrices/coordinates) are, in cuEST,")
w("!    generally GPU DEVICE pointers.  They are exposed as TYPE(c_ptr), VALUE so")
w("!    you may pass either a device address or C_LOC(host_array).")
w("!  * The two workspace structs are interoperable derived types (below).")
w("!  * Enumerators are PUBLIC INTEGER(c_int) PARAMETERs with their C names.")
w("!")
w("!  Build:  gfortran -c cuest.f90     (produces cuest.mod)")
w("!  Link :  ... -L<pkg>/lib -lcuest -Wl,-rpath,<pkg>/lib")
w("! ============================================================================")
w("module cuest")
w("    use, intrinsic :: iso_c_binding")
w("    implicit none")
w("    public")
w("")
w("    ! ---- library version (compile-time, from the headers) ----------------")
w(f"    integer(c_int), parameter :: CUEST_VER_MAJOR = {ver[0]}")
w(f"    integer(c_int), parameter :: CUEST_VER_MINOR = {ver[1]}")
w(f"    integer(c_int), parameter :: CUEST_VER_PATCH = {ver[2]}")
w("")
w("    ! ======================================================================")
w("    !  Enumerations (cuestStatus_t, handle/attribute ids, modes, ...)")
w("    ! ======================================================================")
renamed = []
for tname, consts, h in enum_defs:
    w(f"    ! ---- {tname}")
    for cname, cval in consts:
        fn, orig = fort_name(cname)
        if orig:
            renamed.append((orig, fn))
            w(f"    ! C name (shortened to fit Fortran's 63-char id limit): {orig}")
        w(f"    integer(c_int), parameter :: {fn} = {cval}")
    w("")

w("    ! ======================================================================")
w("    !  Interoperable structs (workspace_api.h)")
w("    ! ======================================================================")
w("    type, bind(C) :: cuestWorkspace_t")
w("        integer(c_intptr_t) :: hostBuffer             = 0_c_intptr_t")
w("        integer(c_size_t)   :: hostBufferSizeInBytes  = 0_c_size_t")
w("        integer(c_intptr_t) :: deviceBuffer           = 0_c_intptr_t")
w("        integer(c_size_t)   :: deviceBufferSizeInBytes= 0_c_size_t")
w("    end type cuestWorkspace_t")
w("")
w("    type, bind(C) :: cuestWorkspaceDescriptor_t")
w("        integer(c_size_t)   :: hostBufferSizeInBytes  = 0_c_size_t")
w("        integer(c_size_t)   :: deviceBufferSizeInBytes= 0_c_size_t")
w("    end type cuestWorkspaceDescriptor_t")
w("")
w("    ! ======================================================================")
w("    !  C function interfaces")
w("    ! ======================================================================")
w("    interface")
w("")
cur_h = None
for name, arglist, h in funcs:
    if h != cur_h:
        cur_h = h
        w(f"        ! ---------------------------------------------------------------")
        w(f"        !  {h}")
        w(f"        ! ---------------------------------------------------------------")
    parts = [a[1] for a in arglist]
    head = f"        integer(c_int) function {name}("
    single = head + ", ".join(parts) + ") &"
    if len(single) <= 128:
        w(single)
    else:
        w(f"        integer(c_int) function {name}( &")
        indent, line = "                ", "                "
        for i, p in enumerate(parts):
            tok = p + ("," if i < len(parts) - 1 else "")
            if len(line) + len(tok) + 2 > 124 and line.strip():
                w(line.rstrip() + " &")
                line = indent
            line += tok + " "
        w(line.rstrip() + ") &")
    w(f'                bind(C, name="{name}")')
    w(f"            import")
    for sig, an in arglist:
        w(f"            {map_arg(sig, an)}")
    w(f"        end function {name}")
    w("")
w("    end interface")
w("")
w("end module cuest")

open(args.output, "w").write("\n".join(lines) + "\n")

print(f"wrote {args.output}")
print(f"  enums:      {sum(len(c) for _,c,_ in enum_defs)} constants in {len(enum_defs)} enum types")
print(f"  functions:  {len(funcs)}")
print(f"  opaque:     {len(OPAQUE)} void* handle types")
if renamed:
    print("  shortened (>63 chars) identifiers:")
    for o, n in renamed:
        print(f"    {o}\n      -> {n}")
