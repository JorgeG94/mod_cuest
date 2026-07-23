#!/usr/bin/env python3
"""Compare a C reference oracle against a Fortran port, numerically.

Both sides print sections in a shared format (see oracle/oracle_report.h and
common/cuest_sample_utils.f90):

    matrix <label>  -> trace, Frobenius norm, max|A-A^T|, leading block
    array  <label>  -> length, sum, norm, max|a_i|, first values
    scalar <label>  -> value

This parses the numbers rather than diffing text, so the two sides are free to
differ in spacing and in D- vs E-exponent spelling.

    compare.py <c_output> <fortran_output> [tolerance]
"""
import re
import sys

NUM = r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[EeDd][-+]?\d+)?"

# The indentation is significant, not cosmetic. Both reporters emit section
# headers at exactly 2 spaces and fields at exactly 4 (see oracle_report.h and
# cuest_sample_utils.f90). Several upstream samples print unindented
# informational lines of the form "PCG converged residual: 1.2e-05", which a
# looser pattern would silently absorb into whichever section was open --
# comparing a quantity nobody meant to compare, or masking a missing one.
# Anchoring on the exact indent means a port cannot break the parse just by
# printing something chatty.
SECTION = re.compile(r"^ {2}(matrix|array|scalar) (\S.*?)\s*$")
FIELD = re.compile(r"^ {4}([A-Za-z][^:]*?)\s*:\s*(" + NUM + r")\s*$")
VALUES = re.compile(r"^\s+(?:" + NUM + r"\s+)*" + NUM + r"\s*$")


def to_float(s):
    return float(s.replace("D", "E").replace("d", "e"))


def parse(path):
    """-> {section: {"kind":..., "fields": {name: value}, "values": [...]}}"""
    out, cur = {}, None
    for ln in open(path, errors="replace"):
        m = SECTION.match(ln)
        if m:
            cur = f"{m.group(1)} {m.group(2)}"
            out[cur] = {"kind": m.group(1), "fields": {}, "values": []}
            continue
        if cur is None:
            continue
        m = FIELD.match(ln)
        if m:
            out[cur]["fields"][m.group(1).strip()] = to_float(m.group(2))
            continue
        if ln.strip() and VALUES.match(ln):
            out[cur]["values"] += [to_float(x) for x in ln.split()]
    return out


def rel(x, y):
    d = max(abs(x), abs(y))
    return 0.0 if d == 0.0 else abs(x - y) / d


# Fields that describe shape rather than magnitude. They must match exactly,
# but they must not set the scale a section is judged against.
COUNT_FIELDS = ("length", "dimension")


def section_scale(sec):
    """The natural magnitude of the object a section describes.

    A purely relative test is wrong for quantities that are analytically zero.
    The sum of a translationally-invariant gradient, or max|A-A^T| for a
    symmetric matrix, is roundoff: two correct implementations summing the same
    bit-identical elements in a different order land on 5.8e-15 and 2.2e-15,
    which "differ" by 62% while being equally right. Judging such a quantity
    against the size of the object it came from -- the norm, the trace, the
    largest element -- rather than against itself, distinguishes noise from a
    real disagreement without hiding one.
    """
    vals = [abs(v) for name, v in sec["fields"].items()
            if not any(c in name for c in COUNT_FIELDS)]
    vals += [abs(v) for v in sec["values"]]
    return max(vals) if vals else 0.0


def main(a, b, tol=1e-10):
    A, B = parse(a), parse(b)
    if not A or not B:
        sys.exit(f"could not parse any sections (C:{len(A)} Fortran:{len(B)})")

    only_c, only_f = sorted(set(A) - set(B)), sorted(set(B) - set(A))
    if only_c or only_f:
        for s in only_c:
            print(f"  MISSING from Fortran output: {s}")
        for s in only_f:
            print(f"  EXTRA in Fortran output:     {s}")
        sys.exit("FAIL: the two outputs do not describe the same quantities")

    worst, bad, checks, noise = 0.0, 0, 0, 0
    for label in sorted(A):
        scale = max(section_scale(A[label]), section_scale(B[label]))
        floor = tol * scale          # absolute floor from the object's own size
        for name, x in A[label]["fields"].items():
            if name not in B[label]["fields"]:
                print(f"  {label}: field '{name}' missing from Fortran output")
                bad += 1
                continue
            y = B[label]["fields"][name]
            r = rel(x, y)
            checks += 1
            below_floor = abs(x - y) <= floor
            ok = r <= tol or below_floor
            if not ok:
                bad += 1
                worst = max(worst, r)
            tag = "ok" if r <= tol else ("ok (noise)" if below_floor else "MISMATCH")
            if tag == "ok (noise)":
                noise += 1
            print(f"  {label:32s} {name:16s} C={x: .12e} F={y: .12e} "
                  f"rel={r:.2e}  {tag}")
        va, vb = A[label]["values"], B[label]["values"]
        if len(va) != len(vb):
            print(f"  {label}: value count differs ({len(va)} vs {len(vb)})")
            bad += 1
        elif va:
            r = max(rel(u, v) for u, v in zip(va, vb))
            checks += len(va)
            ok = r <= tol or max(abs(u - v) for u, v in zip(va, vb)) <= floor
            if not ok:
                bad += 1
                worst = max(worst, r)
            print(f"  {label:32s} {'values':16s} {len(va):4d} numbers"
                  f"{'':25s} max rel={r:.2e}  {'ok' if ok else 'MISMATCH'}")

    print(f"\n{checks} quantities compared across {len(A)} sections")
    if noise:
        print(f"{noise} quantity/quantities agreed only in absolute terms "
              f"(analytically-zero values; see section_scale)")
    print(f"worst UNEXPLAINED relative difference: {worst:.3e}   "
          f"tolerance: {tol:.1e}")
    if bad:
        sys.exit(f"FAIL: {bad} quantity/quantities disagree")
    print("PASS: Fortran port matches the C reference")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2],
         float(sys.argv[3]) if len(sys.argv) > 3 else 1e-10)
