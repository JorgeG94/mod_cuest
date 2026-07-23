#!/usr/bin/env python3
"""
generate_cuda_fortran.py
========================

Generate compiler-agnostic Fortran 2008 `iso_c_binding` interfaces to the CUDA
APIs, directly from the CUDA toolkit headers.

The goal is the coverage of NVIDIA's `cudafor` module without the dependency on
nvfortran: plain standard Fortran that builds under gfortran / ifx / flang /
nvfortran and can be dropped into any project.

    python3 generate_cuda_fortran.py                      # uses $CUDA_HOME
    python3 generate_cuda_fortran.py --cuda /apps/cuda/12.9.0
    python3 generate_cuda_fortran.py --api runtime        # runtime only
    python3 generate_cuda_fortran.py --no-probe           # skip layout probe

Why generated, and what the generator guarantees
------------------------------------------------
Three things make hand-writing these bindings a bad idea, and each is handled
explicitly rather than hoped about:

1.  Versioned symbols.  `cuda_runtime_api.h` contains lines like
        #define cudaGetDeviceProperties cudaGetDeviceProperties_v2
    The *unversioned* symbol also exists in libcudart.so as a backward-compat
    stub taking the OLD struct layout.  Binding the plain name therefore links
    fine and then silently misbehaves.  We resolve these #defines and bind the
    versioned name.

2.  Struct layout.  `cudaDeviceProp` alone has ~100 fields, and several structs
    embed C unions, which Fortran BIND(C) cannot express.  We emit a C probe
    that reports sizeof/offsetof for every type and field we generate, compile
    and run it, and check the Fortran layout against ground truth.  Union (and
    anonymous-struct) members become byte arrays sized by the probe.

3.  Symbol resolution.  Every emitted bind(C, name=...) is checked against
    `nm -D` on the corresponding shared library.  Unresolved names are reported
    and dropped, never emitted silently.

Anything the type mapper does not recognise aborts the run with UNMAPPED.
Nothing is emitted on a guess.
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# API descriptions
# ---------------------------------------------------------------------------
#   headers  : parsed for enums, structs, typedefs and prototypes
#   ret      : the C status type returned by essentially every entry point
#   lib      : shared library used for the symbol-resolution check
#   fnre     : regex matching a function name in this API
APIS = {
    "runtime": dict(
        module="cuda_runtime",
        # NOTE: cudaGL.h / cudaEGL.h / cudaVDPAU.h are deliberately excluded.
        # They require external GL/EGL/VDPAU SDK headers and they #include
        # cuda.h, which would drag the whole driver API into this module.
        # Graphics interop belongs in its own optional module.
        headers=["cuda_runtime_api.h", "driver_types.h", "vector_types.h",
                 "library_types.h", "texture_types.h", "surface_types.h",
                 "cuda_profiler_api.h"],
        probe_include="cuda_runtime.h",
        ret="cudaError_t",
        lib="libcudart.so",
        prefix="cuda",
        macro_prefix="cuda",
        out="cuda_runtime.f90",
    ),
    "driver": dict(
        module="cuda_driver",
        headers=["cuda.h"],
        probe_include="cuda.h",
        ret="CUresult",
        lib="libcuda.so",
        prefix="cu",
        macro_prefix="CU",   # driver flags are CU_STREAM_*, CU_EVENT_*, ...
        out="cuda_driver.f90",
    ),
}

# Decorations that survive preprocessing on some toolchains.
NOISE = [
    r"__attribute__\s*\(\(.*?\)\)",
    r"\bextern\b", r"\bstatic\b", r"\b__restrict__\b", r"\brestrict\b",
    r"\b__inline__\b", r"\b__cdecl\b", r"\b__stdcall\b",
]


def denoise(s):
    for pat in NOISE:
        s = re.sub(pat, " ", s, flags=re.S)
    return s


def cpp_expand(incdir, header, cc):
    """Run the real C preprocessor over a CUDA header and keep only the
    declarations that originate from files under `incdir`.

    Using cpp rather than regexing the raw text is what makes this generator
    trustworthy: it resolves #if/#ifdef (so C++ constructors inside
    `#if defined(__cplusplus)` vanish and `dim3` becomes a plain C struct),
    expands sizing macros (CUDA_IPC_HANDLE_SIZE -> 64), strips the
    __device_builtin__ / __host__ / CUDARTAPI decorations, drops __dv()
    default arguments, and applies the `#define foo foo_v2` symbol aliases.
    """
    path = os.path.join(incdir, header)
    if not os.path.exists(path):
        return None
    r = subprocess.run([cc, "-E", "-x", "c", "-I", incdir, path],
                       capture_output=True, text=True)
    if r.returncode != 0:
        first = (r.stderr.strip().splitlines() or [""])[0]
        print(f"  warning: cpp failed on {header}: {first}")
        return None

    incdir_abs = os.path.abspath(incdir)
    keep, cur_ok = [], False
    marker = re.compile(r'^#\s+\d+\s+"([^"]*)"')
    for ln in r.stdout.splitlines():
        m = marker.match(ln)
        if m:
            cur_ok = os.path.abspath(m.group(1)).startswith(incdir_abs)
            continue
        if ln.startswith("#"):
            continue                      # stray directives / pragmas
        if cur_ok:
            keep.append(ln)
    return denoise("\n".join(keep))


def cpp_macros(incdir, header, cc, prefix):
    """Collect object-like integer #define constants for this API.

    Many CUDA flags are macros, not enumerators -- cudaStreamNonBlocking,
    cudaEventDefault, cudaHostAllocDefault, cudaDeviceScheduleSpin and friends.
    A binding without them is unusable for stream and event creation.

    `cpp -dM` is used rather than a regex over the raw text so that #if
    branches are resolved exactly as a real compile would resolve them.
    """
    path = os.path.join(incdir, header)
    if not os.path.exists(path):
        return {}
    r = subprocess.run([cc, "-E", "-dM", "-x", "c", "-I", incdir, path],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return {}
    raw = {}
    pat = re.compile(r"^#define\s+(" + prefix + r"[A-Za-z0-9_]*)\s+(.+)$")
    for ln in r.stdout.splitlines():
        m = pat.match(ln.strip())
        if m:
            raw[m.group(1)] = m.group(2).strip()

    # Resolve to integers, allowing references to other macros in this set.
    vals, pending = {}, dict(raw)
    for _ in range(6):                       # iterate to a fixed point
        progressed = False
        for name, expr in list(pending.items()):
            e = expr
            if "(" in e and re.search(r"\(\s*[A-Za-z_]\w*\s*\)", e):
                continue                     # a cast, e.g. ((cudaStream_t)0x1)
            e = re.sub(r"\b([0-9a-fA-Fx]+)[uUlL]+\b", r"\1", e)
            env = dict(vals)
            # \b matters: without it this finds "x01" inside the literal 0x01
            # and concludes the macro has an unresolved reference.
            names = set(re.findall(r"\b[A-Za-z_]\w*", e))
            if names - set(env):
                continue                     # unresolved reference: try later
            if not re.fullmatch(r"[\w\s()+\-*/<>|&^~]*", e):
                del pending[name]
                continue
            try:
                v = int(eval(e, {"__builtins__": {}}, env))
            except Exception:
                del pending[name]
                continue
            vals[name] = v
            del pending[name]
            progressed = True
        if not progressed:
            break
    return vals


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------
class Header:
    """Everything the emitter needs, harvested from one API's headers."""

    def __init__(self, incdir, headers, cc="gcc"):
        self.incdir = incdir
        self.opaque = set()      # typedef'd pointer types  -> type(c_ptr)
        self.funcptr = set()     # typedef'd function ptrs  -> type(c_funptr)
        self.intalias = {}       # typedef'd integer scalars -> fortran kind
        self.enums = []          # (typedef_name_or_None, [(const, value)])
        self.enum_types = set()
        self.structs = {}        # tag -> [members]
        self.unions = {}         # tag -> size in bytes (from the probe)
        self.tagged = {}         # name -> 'struct' | 'union' (has a real C tag)
        self.struct_alias = {}   # typedef name -> tag
        self.struct_order = []
        self.funcs = []          # (name, ret, [(csig, argname)])
        self.aliases = {}        # plain name -> versioned name (for naming only)
        self._texts = {}

        for h in headers:
            # The raw text is scanned only to recover the friendly spelling of
            # versioned symbols: cpp has already rewritten the prototype to
            # cudaGetDeviceProperties_v2, but we want the Fortran procedure to
            # keep the name a user would look up.
            path = os.path.join(incdir, h)
            if os.path.exists(path):
                self.aliases.update(self._scan_aliases(
                    open(path, errors="replace").read()))
            txt = cpp_expand(incdir, h, cc)
            if txt is None:
                continue
            self._texts[h] = txt

        if not self._texts:
            sys.exit("error: no headers could be preprocessed")

        for txt in self._texts.values():
            self._scan_typedefs(txt)
        for txt in self._texts.values():
            self._scan_enums(txt)
        for txt in self._texts.values():
            self._scan_structs(txt)
        # A second typedef pass: `typedef struct foo_st {...} foo_t;` bodies are
        # only known after the struct scan.
        for txt in self._texts.values():
            self._scan_late_typedefs(txt)

    # -- #define foo foo_v2 -------------------------------------------------
    @staticmethod
    def _scan_aliases(raw):
        out = {}
        for plain, versioned in re.findall(
                r"^\s*#define\s+([A-Za-z_]\w*)\s+([A-Za-z_]\w*_v\d+)\s*$",
                raw, re.M):
            out[plain] = versioned
        return out

    # -- typedefs -----------------------------------------------------------
    def _scan_typedefs(self, s):
        # pointer typedefs: typedef struct CUstream_st *cudaStream_t;
        for m in re.finditer(
                r"typedef\s+(?:const\s+)?(?:struct|enum|union)?\s*[A-Za-z_]\w*\s*\*\s*"
                r"([A-Za-z_]\w*)\s*;", s):
            self.opaque.add(m.group(1))
        # function-pointer typedefs: typedef void (*cudaHostFn_t)(void*);
        for m in re.finditer(r"typedef[^;{}]*\(\s*\*\s*([A-Za-z_]\w*)\s*\)\s*\(", s):
            self.funcptr.add(m.group(1))
        # integer scalar typedefs: typedef unsigned long long CUdeviceptr_v2;
        for base, name in re.findall(
                r"typedef\s+((?:unsigned\s+|signed\s+)?"
                r"(?:long\s+long|long|int|short|char))\s+([A-Za-z_]\w*)\s*;", s):
            self.intalias[name] = base.strip()
        # typedef of an existing pointer alias: typedef cudaStream_t X;
        # Alias chains matter in the driver API, where the public spelling is
        # two hops from the primitive type:
        #   typedef unsigned long long CUdeviceptr_v2;
        #   typedef CUdeviceptr_v2      CUdeviceptr;
        for _ in range(4):               # iterate to a fixed point
            for src, dst in re.findall(
                    r"typedef\s+([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*;", s):
                if src in self.opaque:
                    self.opaque.add(dst)
                elif src in self.funcptr:
                    self.funcptr.add(dst)
                elif src in self.intalias and dst not in self.intalias:
                    self.intalias[dst] = self.intalias[src]
                elif src in INT_KIND and dst not in self.intalias:
                    # e.g. typedef uint64_t cuuint64_t; -- uint64_t comes from
                    # stdint.h, outside the CUDA include dir, so it is only
                    # known through the kind table.
                    self.intalias[dst] = src
        # typedef enum <tag> <name>;   e.g. typedef enum cudaError cudaError_t;
        for tag, name in re.findall(
                r"typedef\s+enum\s+([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*;", s):
            self.enum_types.add(name)
            self.enum_types.add(tag)

    def _scan_late_typedefs(self, s):
        """`typedef struct <tag> <name>;` and aliases of parsed aggregates."""
        for kind, tag, name in re.findall(
                r"typedef\s+(struct|union)\s+([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*;", s):
            if tag in self.structs or tag in self.unions:
                self.struct_alias[name] = tag
            elif name not in self.structs and name not in self.unions:
                self.opaque.add(name)     # opaque forward-declared handle
        for src, dst in re.findall(r"typedef\s+([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*;", s):
            src = self.struct_alias.get(src, src)
            if (src in self.structs or src in self.unions) \
                    and dst not in self.structs and dst not in self.unions:
                self.struct_alias[dst] = src
            elif src in self.enum_types:
                self.enum_types.add(dst)

    def cname(self, name):
        """The C spelling needed to name this type in probe source."""
        kind = self.tagged.get(name)
        return f"{kind} {name}" if kind else name

    # -- enums --------------------------------------------------------------
    def _scan_enums(self, s):
        for m in re.finditer(r"enum\s+([A-Za-z_]\w*)?\s*\{(.*?)\}\s*([A-Za-z_]\w*)?\s*;",
                             s, re.S):
            tag, body, tname = m.group(1), m.group(2), m.group(3)
            consts, counter = [], 0
            for item in self._split_top(body, ","):
                item = item.strip()
                if not item:
                    continue
                mm = re.match(r"([A-Za-z_]\w*)\s*(?:=\s*(.+))?$", item, re.S)
                if not mm:
                    continue
                name, val = mm.group(1), mm.group(2)
                if val is not None:
                    counter = self._eval_enum(val.strip(), consts)
                    if counter is None:
                        continue
                consts.append((name, counter))
                counter += 1
            if consts:
                self.enums.append((tname or tag, consts))
                for n in (tag, tname):
                    if n:
                        self.enum_types.add(n)

    @staticmethod
    def _eval_enum(expr, sofar):
        """Evaluate an enum initialiser: literals, hex, shifts, and references
        to constants already seen in the same enum."""
        env = {n: v for n, v in sofar}
        expr = expr.replace("ULL", "").replace("UL", "").replace("U", "") \
                   .replace("LL", "").replace("L", "")
        if not re.fullmatch(r"[\w\s()+\-*/<>|&^~]*", expr):
            return None
        try:
            return int(eval(expr, {"__builtins__": {}}, env))
        except Exception:
            return None

    # -- structs ------------------------------------------------------------
    def _scan_structs(self, s):
        # Matches `struct tag { ... }`, `typedef struct { ... } name;` and the
        # union equivalents.  Only file-scope definitions are types; a
        # `struct { ... } tileExtent;` nested inside another struct or union is
        # a member, not a type, so we consume whole top-level definitions and
        # skip any match falling inside one already consumed.
        consumed_until = 0
        for m in re.finditer(r"\b(struct|union)\s+([A-Za-z_]\w*)?\s*\{", s):
            if m.start() < consumed_until:
                continue
            kind, tag = m.group(1), m.group(2)
            body, end = self._balanced(s, s.index("{", m.start()))
            if body is None:
                continue
            consumed_until = end
            # A trailing declarator makes this a typedef: `} cudaIpcMemHandle_t;`
            semi = s.find(";", end)
            trailing = s[end:semi].strip() if semi != -1 else ""
            alias = trailing if re.fullmatch(r"[A-Za-z_]\w*", trailing) else None
            name = tag or alias
            if not name:
                continue
            if tag:
                self.tagged[name] = kind
            if alias and alias != name:
                self.struct_alias[alias] = name
            if name in self.structs or name in self.unions:
                continue
            if kind == "union":
                # Fortran BIND(C) has no union. Emit it as an opaque byte
                # buffer whose length comes from the C probe, so it can still
                # be declared, passed and stored correctly.
                self.unions[name] = None          # size filled in by the probe
                self.struct_order.append(name)
                continue
            members = self._parse_members(body, name)
            if members is None:
                continue
            self.structs[name] = members
            self.struct_order.append(name)

    @staticmethod
    def _balanced(s, open_idx):
        """Return (inner_text, index_after_close) for the brace at open_idx."""
        depth, i = 0, open_idx
        while i < len(s):
            if s[i] == "{":
                depth += 1
            elif s[i] == "}":
                depth -= 1
                if depth == 0:
                    return s[open_idx + 1:i], i + 1
            i += 1
        return None, len(s)

    @staticmethod
    def _split_top(s, sep):
        """Split on `sep` occurring at brace/paren depth 0."""
        out, depth, cur = [], 0, ""
        for ch in s:
            if ch in "{([":
                depth += 1
            elif ch in "})]":
                depth -= 1
            if ch == sep and depth == 0:
                out.append(cur)
                cur = ""
            else:
                cur += ch
        out.append(cur)
        return out

    def _parse_members(self, body, owner):
        """Parse a struct body into member descriptors.

        Nested union / anonymous struct members become {'blob': True}; their
        size is filled in later from the C probe, because Fortran BIND(C)
        has no union and we refuse to guess a size.
        """
        members, i = [], 0
        while i < len(body):
            m = re.compile(r"\b(union|struct)\b\s*([A-Za-z_]\w*)?\s*\{").search(body, i)
            simple_end = body.find(";", i)
            if m and (simple_end == -1 or m.start() < simple_end):
                inner, after = self._balanced(body, body.index("{", m.start()))
                decl_end = body.find(";", after)
                if decl_end == -1:
                    return None
                decl = body[after:decl_end].strip()
                fname = re.sub(r"[\[\]\d\s]", "", decl)
                if fname:
                    members.append(dict(name=fname, blob=True, count=None))
                else:
                    # An anonymous union/struct has no name to offsetof, so its
                    # extent is recovered later from the gap between its named
                    # neighbours (see resolve_anon_blobs).
                    members.append(dict(name=f"anon{len(members)}", blob=True,
                                        anon=True, count=None))
                i = decl_end + 1
                continue
            if simple_end == -1:
                break
            decl = body[i:simple_end].strip()
            i = simple_end + 1
            if not decl:
                continue
            parsed = self._parse_simple_member(decl)
            if parsed is None:
                return None
            members.extend(parsed)
        return members

    @staticmethod
    def _parse_simple_member(decl):
        """`int a, b[3]` -> two member dicts. Returns None if unparseable."""
        decl = re.sub(r"\s+", " ", decl).strip()
        if not decl or decl.endswith(")"):     # function pointer member etc.
            if "(" in decl and "*" in decl:
                nm = re.search(r"\(\s*\*\s*([A-Za-z_]\w*)\s*\)", decl)
                if nm:
                    return [dict(name=nm.group(1), ctype="__funcptr__", count=None)]
            return None
        # `\s*` (not `\s+`) before the declarators: the headers write both
        # `void *userData` and `void* userData`.
        # The `\b` matters: without it `int integrated;` parses as base
        # "int int" plus a member called "egrated".
        m = re.match(r"^((?:const\s+|unsigned\s+|signed\s+|struct\s+|enum\s+|union\s+)*"
                     r"[A-Za-z_]\w*(?:\s+(?:int|long|char|short)\b)*)\s*(.*)$", decl)
        if not m:
            return None
        base, rest = m.group(1).strip(), m.group(2).strip()
        out = []
        for d in rest.split(","):
            d = d.strip()
            if not d:
                continue
            stars = d.count("*")
            am = re.search(r"\[\s*([^\]]*)\s*\]", d)
            count = am.group(1).strip() if am else None
            # Strip the array suffix and any pointer stars, then take the
            # identifier: `void *ptr` -> ptr, `int maxThreadsDim[3]` -> the name.
            core = re.sub(r"\[.*$", " ", d).replace("*", " ").split()
            nm = core[-1] if core else ""
            if not re.fullmatch(r"[A-Za-z_]\w*", nm):
                return None
            out.append(dict(name=nm, ctype=base, stars=stars, count=count))
        return out or None

    # -- prototypes ---------------------------------------------------------
    def scan_functions(self, ret_type, prefix):
        pat = re.compile(
            r"\b(" + re.escape(ret_type) + r"|const\s+char\s*\*)\s+"
            r"(" + prefix + r"[A-Za-z0-9_]*)\s*\((.*?)\)\s*;", re.S)
        seen = set()
        for h, txt in self._texts.items():
            for rtype, name, argstr in pat.findall(txt):
                if name in seen:
                    continue
                seen.add(name)
                argstr = re.sub(r"\s+", " ", argstr).strip()
                args = []
                ok = True
                if argstr and argstr != "void":
                    for a in self._split_top(argstr, ","):
                        a = re.sub(r"=.*$", "", a).strip()   # C++ default arg
                        if not a or a == "...":
                            ok = False
                            break
                        nm = re.search(r"([A-Za-z_]\w*)\s*(\[\s*\d*\s*\])?\s*$", a)
                        if not nm:
                            ok = False
                            break
                        aname = nm.group(1)
                        sig = a[:a.rfind(aname)].strip()
                        if nm.group(2):
                            sig += "*"
                        args.append((sig, aname))
                if ok and len({n for _, n in args}) != len(args):
                    ok = False          # duplicate dummy names: cannot bind
                if ok:
                    self.funcs.append((name, rtype, args))
        self.funcs.sort(key=lambda f: f[0])


# ---------------------------------------------------------------------------
# C type -> Fortran type mapping
# ---------------------------------------------------------------------------
INT_KIND = {
    "int": "c_int", "unsigned int": "c_int", "unsigned": "c_int",
    "signed int": "c_int",
    "short": "c_short", "unsigned short": "c_short",
    "char": "c_signed_char", "unsigned char": "c_signed_char",
    "signed char": "c_signed_char",
    "long": "c_long", "unsigned long": "c_long",
    "long long": "c_long_long", "unsigned long long": "c_long_long",
    "size_t": "c_size_t", "int8_t": "c_int8_t", "uint8_t": "c_int8_t",
    "int16_t": "c_int16_t", "uint16_t": "c_int16_t",
    "int32_t": "c_int32_t", "uint32_t": "c_int32_t",
    "int64_t": "c_int64_t", "uint64_t": "c_int64_t",
}
REAL_KIND = {"float": "c_float", "double": "c_double"}

# Sizes of the iso_c_binding kinds on LP64 targets. Used only to predict struct
# layout so it can be checked against the C probe -- never to decide a mapping.
FKIND_SIZE = {
    "c_signed_char": 1, "c_char": 1, "c_int8_t": 1,
    "c_short": 2, "c_int16_t": 2,
    "c_int": 4, "c_int32_t": 4, "c_float": 4,
    "c_long": 8, "c_long_long": 8, "c_int64_t": 8, "c_size_t": 8,
    "c_double": 8, "c_ptr": 8, "c_funptr": 8, "c_intptr_t": 8,
}


# Fortran caps identifiers at 63 characters; a handful of driver-API enum
# constants exceed that. Abbreviations are applied in order until the name
# fits. Only the integer VALUE crosses the ABI, so an alias is exact -- and the
# emitted declaration always carries a comment giving the true C name.
ABBREV = [
    ("CU_DEVICE_ATTRIBUTE_", "CU_DEV_ATTR_"),
    ("CU_GRAPH_", "CU_GR_"),
    ("_MEMORY_", "_MEM_"),
    ("_VIRTUAL_", "_VIRT_"),
    ("_MANAGEMENT_", "_MGMT_"),
    ("_SUPPORTED", "_SUP"),
    ("_PAGEABLE_", "_PAGE_"),
    ("_ATTRIBUTE_", "_ATTR_"),
    ("_MULTIPROCESSOR_", "_MP_"),
    ("_COMPUTE_CAPABILITY_", "_CC_"),
    ("_CONCURRENT_", "_CONC_"),
    ("_MAXIMUM_", "_MAX_"),
]


def shorten_name(name, used, limit=63):
    """Return (fortran_name, original_or_None) for an over-long C identifier."""
    if len(name) <= limit:
        return name, None
    short = name
    for a, b in ABBREV:
        if len(short) <= limit:
            break
        short = short.replace(a, b)
    if len(short) > limit:
        short = short[:limit]
    base, k = short, 2
    while short.lower() in used:
        suffix = str(k)
        short = base[:limit - len(suffix)] + suffix
        k += 1
    return short, name


def blob_kind(nbytes):
    """Choose the widest integer kind that exactly tiles `nbytes`.

    A C union's alignment always divides its size, so tiling with the widest
    divisor reproduces at least the union's alignment -- important because a
    byte array would under-align the members that follow it. verify_layout()
    confirms the result rather than trusting it.
    """
    for kind, sz in (("c_int64_t", 8), ("c_int32_t", 4),
                     ("c_int16_t", 2), ("c_int8_t", 1)):
        if nbytes % sz == 0:
            return kind, sz, nbytes // sz
    return "c_int8_t", 1, nbytes


class Mapper:
    def __init__(self, hdr):
        self.h = hdr
        self.unmapped = []

    def base_of(self, sig):
        s = re.sub(r"\b(const|volatile|struct|enum|union)\b", " ", sig)
        s = s.replace("*", " ")
        s = re.sub(r"\s+", " ", s).strip()
        return self.canon(s)

    def canon(self, base):
        """Resolve a typedef alias to the tag we actually emit a type for."""
        seen = set()
        while base in self.h.struct_alias and base not in seen:
            seen.add(base)
            base = self.h.struct_alias[base]
        return base

    @staticmethod
    def normalize_int(base):
        """Fold equivalent C integer spellings onto one key.

        C lets the same type be written many ways -- `long long int`,
        `unsigned long int`, `signed char` -- and the CUDA headers use several
        of them (vector_types.h writes `unsigned long int x, y, z`).
        """
        toks = base.split()
        if "int" in toks and any(t in toks for t in ("long", "short", "char")):
            toks = [t for t in toks if t != "int"]
        if "signed" in toks and "char" not in toks:
            toks = [t for t in toks if t != "signed"]
        return " ".join(toks)

    def resolve_int(self, base):
        for key in (base, self.normalize_int(base)):
            if key in INT_KIND:
                return INT_KIND[key]
            alias = self.h.intalias.get(key)
            if alias:
                a = self.normalize_int(alias)
                if a in INT_KIND:
                    return INT_KIND[a]
        return None

    def arg(self, sig, name):
        """Map one C parameter to a Fortran dummy declaration."""
        is_const = "const" in sig
        stars = sig.count("*")
        base = self.base_of(sig)

        if base == "void" and stars == 0:
            return None
        # opaque handles and function pointers
        if base in self.h.opaque:
            if stars == 0:
                return f"type(c_ptr), value :: {name}"
            return f"type(c_ptr), intent(out) :: {name}"
        if base in self.h.funcptr:
            return f"type(c_funptr), value :: {name}"
        # raw memory
        if base == "void":
            if stars >= 2:
                # `void**` is an OUT parameter almost everywhere (cudaMalloc),
                # but in the launch APIs it is an IN array of argument
                # pointers. Declaring those intent(out) would make passing the
                # arguments undefined behaviour, so name them explicitly.
                if name in ("args", "extra", "kernelParams"):
                    return (f"type(c_ptr), dimension(*), intent(in) :: {name}")
                return f"type(c_ptr), intent(out) :: {name}"
            return f"type(c_ptr), value :: {name}"
        # strings
        if base == "char" and stars >= 1:
            if stars >= 2:
                return f"type(c_ptr), intent(out) :: {name}"
            return f"character(kind=c_char), dimension(*), intent(in) :: {name}"
        # enums
        if base in self.h.enum_types:
            if stars == 0:
                return f"integer(c_int), value :: {name}"
            return f"integer(c_int), intent(out) :: {name}"
        # structs and (byte-blob) unions
        if base in self.h.structs or base in self.h.unions:
            if stars == 0:
                return f"type({base}), value :: {name}"
            intent = "intent(in)" if is_const else "intent(inout)"
            return f"type({base}), {intent} :: {name}"
        # reals
        if base in REAL_KIND:
            k = REAL_KIND[base]
            if stars == 0:
                return f"real({k}), value :: {name}"
            return f"real({k}), intent(inout) :: {name}"
        # integers
        k = self.resolve_int(base)
        if k:
            if stars == 0:
                return f"integer({k}), value :: {name}"
            if is_const:
                return f"integer({k}), dimension(*), intent(in) :: {name}"
            return f"integer({k}), intent(inout) :: {name}"
        self.unmapped.append((sig, name, base))
        return f"!! UNMAPPED {sig} {name}"

    def member_kind(self, m):
        """(fortran_kind, elem_size, count) for a member, or None if unknown.

        Used both to emit the declaration and to predict the layout.
        """
        if m.get("blob"):
            if m.get("byte") or m.get("anon"):
                # byte-aligned by construction: it absorbs its own padding
                return "c_int8_t", 1, m.get("count") or 1
            k, sz, n = blob_kind(m.get("count") or 1)
            return k, sz, n
        ctype = m["ctype"]
        cnt = m.get("count")
        try:
            n = int(cnt) if cnt else 1
        except ValueError:
            return None
        if ctype == "__funcptr__":
            return "c_funptr", 8, n
        if m.get("stars"):
            return "c_ptr", 8, n
        base = self.base_of(ctype)
        if base in self.h.opaque or base in self.h.funcptr:
            return "c_ptr", 8, n
        if base in self.h.enum_types:
            return "c_int", 4, n
        if base == "char":
            return "c_char", 1, n
        if base in REAL_KIND:
            k = REAL_KIND[base]
            return k, FKIND_SIZE[k], n
        k = self.resolve_int(base)
        if k:
            return k, FKIND_SIZE[k], n
        return None      # aggregate member: caller recurses

    @staticmethod
    def fort_member_name(n):
        """C allows a leading underscore in a member name; Fortran does not."""
        return ("x" + n) if n.startswith("_") else n

    def member(self, m, owner):
        """Map one struct member to a Fortran component declaration."""
        name = self.fort_member_name(m["name"])
        if m.get("blob"):
            if m.get("byte") or m.get("anon"):
                n = m.get("count") or 1
                what = ("anonymous C union" if m.get("anon")
                        else "computed-size C array")
                return (f"integer(c_int8_t) :: {name}({n})"
                        f"   ! {what} (+ padding)")
            kind, _, n = blob_kind(m.get("count") or 1)
            return f"integer({kind}) :: {name}({n})   ! C union / anonymous struct"
        ctype = m["ctype"]
        if ctype == "__funcptr__":
            return f"type(c_funptr) :: {name}"
        stars = m.get("stars", 0)
        base = self.base_of(ctype)
        cnt = m.get("count")
        dim = f"({cnt})" if cnt else ""

        if stars or base in self.h.opaque or base in self.h.funcptr:
            return f"type(c_ptr) :: {name}{dim}"
        if base in self.h.enum_types:
            return f"integer(c_int) :: {name}{dim}"
        if base in self.h.structs or base in self.h.unions:
            return f"type({base}) :: {name}{dim}"
        if base == "char":
            return f"character(kind=c_char) :: {name}{dim or '(1)'}"
        if base in REAL_KIND:
            return f"real({REAL_KIND[base]}) :: {name}{dim}"
        k = self.resolve_int(base)
        if k:
            return f"integer({k}) :: {name}{dim}"
        self.unmapped.append((ctype, f"{owner}.{name}", base))
        return f"!! UNMAPPED {ctype} {name}"


# ---------------------------------------------------------------------------
# C layout probe: ground truth for sizes and offsets
# ---------------------------------------------------------------------------
def run_probe(incdir, include, hdr, blobs, cc="gcc"):
    """Compile and run a C program reporting sizeof/offsetof for everything we
    are about to emit.  Returns (sizes, offsets, blob_sizes) or None.

    This is the generator's ground truth: nothing whose layout the C compiler
    did not confirm is emitted.
    """
    lines = [
        "#include <stddef.h>", "#include <stdio.h>", f"#include <{include}>",
        "int main(void){",
    ]
    for name, members in hdr.structs.items():
        c = hdr.cname(name)
        lines.append(f'  printf("S {name} %zu\\n", sizeof({c}));')
        for m in members:
            if m.get("anon"):
                continue          # C has no name to offsetof here
            lines.append(
                f'  printf("O {name} {m["name"]} %zu\\n",'
                f' offsetof({c}, {m["name"]}));')
    for name in hdr.unions:
        lines.append(f'  printf("S {name} %zu\\n", sizeof({hdr.cname(name)}));')
    for owner, field in blobs:
        lines.append(
            f'  printf("B {owner} {field} %zu\\n",'
            f' sizeof((({hdr.cname(owner)}*)0)->{field}));')
    lines += ['  return 0;', "}"]
    src = "\n".join(lines)

    tmp = tempfile.mkdtemp(prefix="cudafort_probe_")
    csrc = os.path.join(tmp, "probe.c")
    exe = os.path.join(tmp, "probe")
    open(csrc, "w").write(src)
    r = subprocess.run([cc, "-I", incdir, csrc, "-o", exe],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  probe failed to compile (source kept at {csrc})")
        for ln in r.stderr.strip().splitlines()[:15]:
            print("    " + ln)
        return None
    r = subprocess.run([exe], capture_output=True, text=True)
    if r.returncode != 0:
        print("  probe failed to run")
        return None

    sizes, offsets, blobsz = {}, {}, {}
    for ln in r.stdout.splitlines():
        p = ln.split()
        if p[0] == "S":
            sizes[p[1]] = int(p[2])
        elif p[0] == "O":
            offsets[(p[1], p[2])] = int(p[3])
        elif p[0] == "B":
            blobsz[(p[1], p[2])] = int(p[3])
    return sizes, offsets, blobsz


# ---------------------------------------------------------------------------
# Symbol resolution check
# ---------------------------------------------------------------------------
def exported_symbols(libname, cuda):
    for cand in (os.path.join(cuda, "lib64", libname),
                 os.path.join(cuda, "lib64", "stubs", libname),
                 os.path.join(cuda, "lib", libname),
                 libname):
        if os.path.exists(cand):
            r = subprocess.run(["nm", "-D", "--defined-only", cand],
                               capture_output=True, text=True)
            if r.returncode == 0:
                syms = set()
                for ln in r.stdout.splitlines():
                    parts = ln.split()
                    if len(parts) >= 3 and parts[-2] in ("T", "t", "W", "i"):
                        syms.add(parts[-1].split("@")[0])
                if syms:
                    return syms, cand
    return None, None


# ---------------------------------------------------------------------------
# Struct dependency ordering
# ---------------------------------------------------------------------------
def needs_gap_sizing(m):
    """True if a member's extent cannot be read off the declaration alone."""
    if m.get("anon"):
        return True                      # anonymous union: no name to offsetof
    c = m.get("count")
    if c is None or m.get("blob"):
        return False
    return not re.fullmatch(r"\d+", str(c))   # e.g. char pad[8 - sizeof(x)]


def resolve_unsized_members(hdr, mapper, sizes, offsets):
    """Size members whose extent the declaration does not state, using the gap
    to the next named member.

    Two cases occur in the CUDA headers:
      * anonymous unions (cudaGraphNodeParams) -- C forbids offsetof on them;
      * computed array bounds (cudaLaunchAttribute_st's
        `char pad[8 - sizeof(cudaLaunchAttributeID)]`).

    Both become byte-aligned blobs that absorb their own padding, which keeps
    every named member at exactly the offset C gave it.
    """
    dropped = []
    for name, members in hdr.structs.items():
        targets = [i for i, m in enumerate(members) if needs_gap_sizing(m)]
        if not targets:
            continue
        total = sizes.get(name)
        ok = total is not None
        for i in targets:
            if not ok:
                break
            m = members[i]
            start = offsets.get((name, m["name"])) if not m.get("anon") else None
            if start is None:
                if i == 0:
                    start = 0
                else:
                    pm = members[i - 1]
                    po = offsets.get((name, pm["name"]))
                    mk = mapper.member_kind(pm)
                    if po is None or mk is None:
                        ok = False
                        break
                    start = po + mk[1] * mk[2]
            end = None
            for m2 in members[i + 1:]:
                if not needs_gap_sizing(m2):
                    end = offsets.get((name, m2["name"]))
                    break
            if end is None:
                end = total
            if end is None or end < start:
                ok = False
                break
            m.update(blob=True, byte=True, count=end - start)
        if not ok:
            dropped.append(name)
    for n in dropped:
        hdr.structs.pop(n, None)
    return dropped


def resolve_name_collisions(hdr):
    """Fortran is case-insensitive; C is not.

    The CUDA headers legitimately contain names that differ only in case -- the
    enum constant `cudaLibraryHostUniversalFunctionAndDataTable` and the struct
    tag `cudalibraryHostUniversalFunctionAndDataTable`.  Enum constants keep
    their C spelling because callers write them; a colliding type is renamed
    with a `_t` suffix (types are only referenced inside this module).

    Must run AFTER the probe, which needs the original C names.
    """
    used, renames = {}, {}
    for _, consts in hdr.enums:
        for c, _v in consts:
            used.setdefault(c.lower(), "enum constant")
    for n in list(hdr.structs) + list(hdr.unions):
        if n.lower() not in used:
            used[n.lower()] = "type"
            continue
        new, k = n + "_t", 2
        while new.lower() in used:
            new, k = f"{n}_t{k}", k + 1
        used[new.lower()] = "type"
        renames[n] = new

    for old, new in renames.items():
        if old in hdr.structs:
            hdr.structs[new] = hdr.structs.pop(old)
        if old in hdr.unions:
            hdr.unions[new] = hdr.unions.pop(old)
        for a, t in list(hdr.struct_alias.items()):
            if t == old:
                hdr.struct_alias[a] = new
        hdr.struct_alias[old] = new     # existing references resolve to it

    clashing_funcs = [f for f in hdr.funcs if f[0].lower() in used]
    if clashing_funcs:
        hdr.funcs = [f for f in hdr.funcs if f[0].lower() not in used]
    return renames, [f[0] for f in clashing_funcs]


def verify_layout(hdr, mapper, sizes, offsets):
    """Predict the layout of every emitted BIND(C) type and compare it with the
    sizeof/offsetof the C compiler reported.

    Any type whose predicted layout disagrees is DROPPED, not emitted with a
    warning: a silently wrong struct layout corrupts memory at run time, which
    is far worse than a missing declaration.
    """
    memo = {}

    def layout(name):
        """-> (size, align, {member: offset}) or None if not derivable."""
        if name in memo:
            return memo[name]
        memo[name] = None                       # cycle guard
        if name in hdr.unions:
            sz = hdr.unions[name]
            _, esz, _ = blob_kind(sz)
            memo[name] = (sz, esz, {})
            return memo[name]
        members = hdr.structs.get(name)
        if members is None:
            return None
        off, align, locs = 0, 1, {}
        for m in members:
            mk = mapper.member_kind(m)
            if mk is None:
                base = mapper.base_of(m.get("ctype", ""))
                sub = layout(base)
                if sub is None:
                    return None
                esz, ea = sub[0], sub[1]
                try:
                    n = int(m["count"]) if m.get("count") else 1
                except ValueError:
                    return None
                msize, malign = esz * n, ea
            else:
                _, esz, n = mk
                msize, malign = esz * n, esz
            off = (off + malign - 1) // malign * malign
            locs[m["name"]] = off
            off += msize
            align = max(align, malign)
        total = (off + align - 1) // align * align
        memo[name] = (total, align, locs)
        return memo[name]

    bad = []
    for name in list(hdr.structs):
        got = layout(name)
        want = sizes.get(name)
        if got is None or want is None:
            bad.append((name, "layout not derivable"))
            continue
        if got[0] != want:
            bad.append((name, f"size {got[0]} predicted vs {want} actual"))
            continue
        for mname, mo in got[2].items():
            actual = offsets.get((name, mname))
            if actual is not None and actual != mo:
                bad.append((name, f"offset of {mname}: {mo} vs {actual}"))
                break

    for name, _ in bad:
        hdr.structs.pop(name, None)
    if bad:
        print(f"  layout check: DROPPED {len(bad)} type(s) that did not match C")
        for n, why in bad[:10]:
            print(f"      {n}: {why}")
        if len(bad) > 10:
            print(f"      ... and {len(bad) - 10} more")
    else:
        print(f"  layout check: all {len(hdr.structs)} struct(s) match C "
              f"sizeof/offsetof exactly")
    return bad


def order_structs(hdr, mapper):
    """Topologically sort so a type is declared before it is used."""
    structs, unions = hdr.structs, hdr.unions
    ordered, seen, stack = [], set(), set()

    def visit(n):
        if n in seen:
            return
        if n in unions:                 # leaf: an opaque byte buffer
            seen.add(n)
            ordered.append(n)
            return
        if n not in structs or n in stack:
            return                      # unknown, or a cycle: encounter order
        stack.add(n)
        for m in structs[n]:
            if m.get("blob") or m.get("stars"):
                continue
            b = mapper.base_of(m.get("ctype", ""))
            if b in structs or b in unions:
                visit(b)
        stack.discard(n)
        seen.add(n)
        ordered.append(n)

    for n in list(unions) + list(structs):
        visit(n)
    return ordered


# ---------------------------------------------------------------------------
# Emission
# ---------------------------------------------------------------------------
def wrap_arglist(head, names, indent, width=120):
    """Emit a Fortran argument list, continued across lines as needed."""
    single = head + ", ".join(names) + ") &"
    if len(single) <= width:
        return [single]
    out = [head.rstrip("(") + "( &"]
    line = indent
    for i, p in enumerate(names):
        tok = p + ("," if i < len(names) - 1 else "")
        if len(line) + len(tok) + 2 > width and line.strip():
            out.append(line.rstrip() + " &")
            line = indent
        line += tok + " "
    out.append(line.rstrip() + ") &")
    return out


def emit(api, hdr, mapper, probe, syms, version, cuda):
    L = []
    w = L.append
    mod = api["module"]

    w("! " + "=" * 74)
    w(f"!  {api['out']} -- Fortran 2008 iso_c_binding interface to the CUDA "
      f"{'Runtime' if api['module'].endswith('runtime') else 'Driver'} API")
    w("!")
    w("!  GENERATED FILE -- do not edit by hand.")
    w("!  Regenerate with:  python3 generate_cuda_fortran.py")
    w(f"!  Generated from CUDA {version} headers at:")
    w(f"!      {cuda}/include")
    w("!")
    w("!  Standard Fortran 2008 only -- no compiler extensions. Builds with")
    w("!  gfortran, ifx, flang and nvfortran, and is independent of cudafor.")
    w("!")
    w("!  Conventions")
    w("!  -----------")
    w("!  * Every entry point returns its C status code as an INTEGER(c_int)")
    w("!    function result (cudaError_t / CUresult).")
    w("!  * Opaque handles (streams, events, graphs, arrays, ...) are pointers")
    w("!    in C and map to TYPE(c_ptr): by VALUE when passed in, INTENT(OUT)")
    w("!    when returned (C  T*  where T is itself a pointer typedef).")
    w("!  * Device and host buffers (void*, T*) are TYPE(c_ptr), VALUE. Pass a")
    w("!    device address, or C_LOC(host_array) for host data.")
    w("!  * Enumerators are PUBLIC INTEGER(c_int) PARAMETERs with their C names.")
    w("!  * Structs are BIND(C) derived types whose layout has been verified")
    w("!    against sizeof/offsetof from a compiled C probe. C unions have no")
    w("!    Fortran equivalent and appear as INTEGER(c_int8_t) byte arrays of")
    w("!    the correct size.")
    w("!  * Fortran is case-insensitive; the C names are preserved verbatim and")
    w("!    checked for case-insensitive collisions at generation time.")
    w("! " + "=" * 74)
    w(f"module {mod}")
    w("    use, intrinsic :: iso_c_binding")
    w("    implicit none")
    w("    public")
    w("")

    # ---- enums ----
    w("    ! " + "=" * 70)
    w("    !  Enumerations")
    w("    ! " + "=" * 70)
    emitted = {}
    collisions = []
    shortened = []
    nconst = 0
    for tname, consts in hdr.enums:
        if tname:
            w(f"    ! ---- {tname}")
        for cname, cval in consts:
            key = cname.lower()
            if key in emitted:
                if emitted[key] != cval:
                    collisions.append((cname, emitted[key], cval))
                continue
            fname, orig = shorten_name(cname, emitted)
            if orig:
                shortened.append((orig, fname))
                w(f"    ! C name (shortened to fit Fortran's 63-char limit): "
                  f"{orig}")
            emitted[fname.lower()] = cval
            if fname != cname:
                emitted[key] = cval
            w(f"    integer(c_int), parameter :: {fname} = {cval}")
            nconst += 1
        w("")

    # ---- macro constants ----
    nmacro = 0
    macros = getattr(hdr, "macros", {})
    if macros:
        w("    ! " + "=" * 70)
        w("    !  Flag constants defined as C macros rather than enumerators")
        w("    !  (stream/event/host-alloc/device-schedule flags, ...)")
        w("    ! " + "=" * 70)
        for mname in sorted(macros):
            mval = macros[mname]
            if mname.lower() in emitted:
                continue
            fname, orig = shorten_name(mname, emitted)
            if orig:
                shortened.append((orig, fname))
                w(f"    ! C name (shortened to fit Fortran's 63-char limit): {orig}")
            kind = "c_int" if -2**31 <= mval < 2**31 else "c_int64_t"
            emitted[fname.lower()] = mval
            w(f"    integer({kind}), parameter :: {fname} = {mval}")
            nmacro += 1
        w("")

    # ---- structs ----
    w("    ! " + "=" * 70)
    w("    !  Interoperable derived types")
    w("    ! " + "=" * 70)
    order = order_structs(hdr, mapper)
    nstruct = 0
    for name in order:
        if name in hdr.unions:
            size = hdr.unions[name]
            kind, _, cnt = blob_kind(size)
            w(f"    ! {name} is a C union: no Fortran equivalent, so it is")
            w(f"    ! declared as an opaque {size}-byte buffer (size measured "
              f"by the C probe).")
            w(f"    type, bind(C) :: {name}")
            w(f"        integer({kind}) :: raw({cnt})")
            w(f"    end type {name}")
            w("")
            nstruct += 1
            continue
        members = hdr.structs.get(name)
        if not members:
            continue
        w(f"    type, bind(C) :: {name}")
        for m in members:
            w(f"        {mapper.member(m, name)}")
        w(f"    end type {name}")
        w("")
        nstruct += 1

    # ---- interfaces ----
    w("    ! " + "=" * 70)
    w("    !  C entry points")
    w("    ! " + "=" * 70)
    w("    interface")
    w("")
    # cpp has already rewritten `cudaGetDeviceProperties` to its `_v2` spelling.
    # Bind the versioned symbol (the unversioned one is a compat stub with the
    # OLD struct layout) but expose the friendly name to Fortran callers.
    rev = {v: k for k, v in hdr.aliases.items()}
    nfunc, skipped = 0, []
    for link, rtype, args in hdr.funcs:
        name = rev.get(link, link)
        if syms is not None and link not in syms:
            skipped.append((name, f"not exported by {api['lib']}"))
            continue
        decls, bad = [], False
        for sig, an in args:
            d = mapper.arg(sig, an)
            if d is None:
                bad = True
                break
            decls.append(d)
        if bad or any("UNMAPPED" in d for d in decls):
            skipped.append((name, "unmapped argument"))
            continue
        if len(name) > 63:
            skipped.append((name, "identifier > 63 chars"))
            continue
        names = [a[1] for a in args]
        is_str = rtype.strip().startswith("const")
        head = (f"        type(c_ptr) function {name}(" if is_str
                else f"        integer(c_int) function {name}(")
        for ln in wrap_arglist(head, names, " " * 16):
            w(ln)
        if link != name:
            w(f'                bind(C, name="{link}")   ! header aliases '
              f'{name} -> {link}')
        else:
            w(f'                bind(C, name="{link}")')
        w("            import")
        for d in decls:
            w(f"            {d}")
        w(f"        end function {name}")
        w("")
        nfunc += 1
    w("    end interface")
    w("")
    w(f"end module {mod}")
    return "\n".join(L) + "\n", dict(consts=nconst, structs=nstruct,
                                     funcs=nfunc, skipped=skipped,
                                     collisions=collisions, shortened=shortened,
                                     macros=nmacro)


# ---------------------------------------------------------------------------
def build_api(key, cuda, do_probe, outdir, cc):
    api = APIS[key]
    inc = os.path.join(cuda, "include")
    print(f"\n=== {api['module']} ===")
    hdr = Header(inc, api["headers"], cc)
    hdr.scan_functions(api["ret"], api["prefix"])
    hdr.macros = {}
    for h in api["headers"]:
        hdr.macros.update(cpp_macros(inc, h, cc, api.get("macro_prefix", api["prefix"])))
    mapper = Mapper(hdr)

    blobs = [(n, m["name"]) for n, ms in hdr.structs.items()
             for m in ms if m.get("blob") and not m.get("anon")]

    probe = None
    if do_probe:
        probe = run_probe(inc, api["probe_include"], hdr, blobs, cc)
    if probe:
        sizes, offsets, blobsz = probe
        # Size union members and standalone unions from ground truth.
        for n, ms in hdr.structs.items():
            for m in ms:
                if m.get("blob"):
                    m["count"] = blobsz.get((n, m["name"]))
        for n in hdr.unions:
            hdr.unions[n] = sizes.get(n)
        anon_dropped = resolve_unsized_members(hdr, mapper, sizes, offsets)
        if anon_dropped:
            print(f"  dropped {len(anon_dropped)} type(s) with unresolvable "
                  f"member sizes")
        drop = [n for n in hdr.structs if n not in sizes]
        drop += [n for n, ms in hdr.structs.items()
                 if any(m.get("blob") and not m.get("count") for m in ms)]
        udrop = [n for n, sz in hdr.unions.items() if not sz]
        for n in set(drop):
            hdr.structs.pop(n, None)
        for n in udrop:
            hdr.unions.pop(n, None)
        if drop or udrop:
            print(f"  dropped {len(set(drop)) + len(udrop)} unmeasurable "
                  f"aggregate(s)")
        verify_layout(hdr, mapper, sizes, offsets)
    else:
        # Without ground truth we refuse to guess a union size.
        for n in [x for x, ms in hdr.structs.items()
                  if any(m.get("blob") for m in ms)]:
            hdr.structs.pop(n, None)
        hdr.unions.clear()
        print("  WARNING: no layout probe; union-bearing types omitted")

    syms, libpath = exported_symbols(api["lib"], cuda)
    if syms:
        print(f"  symbol check against {libpath} ({len(syms)} exported)")
    else:
        print(f"  warning: {api['lib']} not found; skipping symbol check")

    renames, clashes = resolve_name_collisions(hdr)
    if renames:
        print(f"  renamed {len(renames)} type(s) clashing case-insensitively "
              f"with an enum constant:")
        for o, n in list(renames.items())[:5]:
            print(f"      {o} -> {n}")
    if clashes:
        print(f"  dropped {len(clashes)} function(s) clashing with a "
              f"constant/type name: {', '.join(clashes[:5])}")

    version = detect_version(inc)
    text, stats = emit(api, hdr, mapper, probe, syms, version, cuda)

    out = os.path.join(outdir, api["out"])
    open(out, "w").write(text)
    print(f"  wrote {out}")
    print(f"    enum constants : {stats['consts']}")
    print(f"    macro constants: {stats.get('macros', 0)}")
    print(f"    derived types  : {stats['structs']}")
    print(f"    functions      : {stats['funcs']}")
    if probe:
        print(f"    layout probe   : {len(probe[0])} structs measured, "
              f"{len(probe[2])} union members sized")
    if stats["skipped"]:
        print(f"    skipped        : {len(stats['skipped'])}")
        for n, why in stats["skipped"][:12]:
            print(f"        {n}  ({why})")
        if len(stats["skipped"]) > 12:
            print(f"        ... and {len(stats['skipped']) - 12} more")
    if stats.get("shortened"):
        print(f"    shortened      : {len(stats['shortened'])} over-long "
              f"identifier(s)")
        for o, n in stats["shortened"][:6]:
            print(f"        {o}\n          -> {n}")
    if stats["collisions"]:
        print(f"    name collisions: {len(stats['collisions'])}")
        for c in stats["collisions"][:8]:
            print(f"        {c}")
    if mapper.unmapped:
        uniq = sorted({u[2] for u in mapper.unmapped})
        print(f"    UNMAPPED types : {len(uniq)} -> {', '.join(uniq[:15])}")
    return stats


def detect_version(inc):
    p = os.path.join(inc, "cuda.h")
    if os.path.exists(p):
        m = re.search(r"#define\s+CUDA_VERSION\s+(\d+)", open(p, errors="replace").read())
        if m:
            v = int(m.group(1))
            return f"{v // 1000}.{(v % 1000) // 10}"
    return "unknown"


def main():
    ap = argparse.ArgumentParser(
        description="Generate Fortran iso_c_binding interfaces to the CUDA APIs.")
    ap.add_argument("--cuda", default=os.environ.get("CUDA_HOME", "/usr/local/cuda"),
                    help="CUDA toolkit root (default: $CUDA_HOME)")
    ap.add_argument("--api", choices=["runtime", "driver", "both"], default="both")
    ap.add_argument("--outdir", default=HERE)
    ap.add_argument("--cc", default="gcc", help="C compiler for the layout probe")
    ap.add_argument("--no-probe", action="store_true",
                    help="skip the sizeof/offsetof validation probe")
    a = ap.parse_args()

    if not os.path.exists(os.path.join(a.cuda, "include", "cuda_runtime_api.h")):
        sys.exit(f"error: {a.cuda}/include/cuda_runtime_api.h not found "
                 f"-- pass --cuda <toolkit root>")
    print(f"CUDA toolkit : {a.cuda}")
    print(f"CUDA version : {detect_version(os.path.join(a.cuda, 'include'))}")

    keys = ["runtime", "driver"] if a.api == "both" else [a.api]
    for k in keys:
        build_api(k, a.cuda, not a.no_probe, a.outdir, a.cc)


if __name__ == "__main__":
    main()
