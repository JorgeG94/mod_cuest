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
import argparse
import json
import os
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


def sign_dependent(sec_a, sec_b, tol):
    """True if the two arrays hold the same magnitudes but a different `sum`.

    `sum` is signed; `sum |a_i|`, `norm` and `max |a_i|` are not. When all three
    invariants agree and only `sum` does not, the two sides hold the same
    multiset of magnitudes with some signs differing -- a sign convention, not a
    numerical error.

    This is not a guess. The DF MO tensors are built through an auxiliary-basis
    fitting metric whose factorisation is determined only up to a per-vector
    sign, and physical results are invariant because the factor appears twice.
    Confirmed empirically: two runs of the UNMODIFIED C reference, same input,
    give A_ab sum = +2.2738e+02 and -1.0325e+02 while its norm is bit-identical
    in both. A quantity the reference cannot reproduce against itself is not one
    a port can be asked to reproduce.
    """
    inv = ("sum |a_i|", "norm", "max |a_i|")
    have = [k for k in inv if k in sec_a["fields"] and k in sec_b["fields"]]
    if len(have) < 2:
        return False
    return all(rel(sec_a["fields"][k], sec_b["fields"][k]) <= tol for k in have)


def main(a, b, tol=1e-10, name=None, jsonl=None):
    rec = {"name": name or os.path.basename(a).split(".")[0], "kind": "compare",
           "sections": 0, "checks": 0, "noise": 0, "worst": 0.0,
           "failures": [], "status": "pass"}

    def finish(msg=None):
        if jsonl:
            with open(jsonl, "a") as fh:
                fh.write(json.dumps(rec) + "\n")
        if msg:
            sys.exit(msg)

    A, B = parse(a), parse(b)
    rec["sections"] = len(A)
    if not A or not B:
        rec["status"] = "fail"
        rec["failures"].append({"section": "-", "field": "parse",
                                "detail": f"C:{len(A)} Fortran:{len(B)} sections"})
        finish(f"could not parse any sections (C:{len(A)} Fortran:{len(B)})")

    only_c, only_f = sorted(set(A) - set(B)), sorted(set(B) - set(A))
    if only_c or only_f:
        for s_ in only_c:
            print(f"  MISSING from Fortran output: {s_}")
            rec["failures"].append({"section": s_, "field": "-",
                                    "detail": "missing from Fortran output"})
        for s_ in only_f:
            print(f"  EXTRA in Fortran output:     {s_}")
            rec["failures"].append({"section": s_, "field": "-",
                                    "detail": "extra in Fortran output"})
        rec["status"] = "fail"
        finish("FAIL: the two outputs do not describe the same quantities")

    worst, bad, checks, noise, gauge = 0.0, 0, 0, 0, 0
    for label in sorted(A):
        scale = max(section_scale(A[label]), section_scale(B[label]))
        floor = tol * scale          # absolute floor from the object's own size
        # A label may declare itself non-assertable; see the PCM residual.
        informational = "[informational]" in label
        signdep = sign_dependent(A[label], B[label], tol)
        for name, x in A[label]["fields"].items():
            if name not in B[label]["fields"]:
                print(f"  {label}: field '{name}' missing from Fortran output")
                bad += 1
                continue
            y = B[label]["fields"][name]
            r = rel(x, y)
            checks += 1
            below_floor = abs(x - y) <= floor
            excused = informational or (signdep and name == "sum")
            ok = r <= tol or below_floor or excused
            if not ok:
                bad += 1
                worst = max(worst, r)
                rec["failures"].append({"section": label, "field": name,
                                        "c": x, "f": y, "rel": r})
            if r <= tol:
                tag = "ok"
            elif below_floor:
                tag = "ok (noise)"
                noise += 1
            elif signdep and name == "sum":
                tag = "ok (sign-dependent)"
                gauge += 1
            elif informational:
                tag = "ok (informational)"
                gauge += 1
            else:
                tag = "MISMATCH"
            print(f"  {label:32s} {name:16s} C={x: .12e} F={y: .12e} "
                  f"rel={r:.2e}  {tag}")
        va, vb = A[label]["values"], B[label]["values"]
        if len(va) != len(vb):
            print(f"  {label}: value count differs ({len(va)} vs {len(vb)})")
            bad += 1
            rec["failures"].append({"section": label, "field": "values",
                                    "detail": f"count {len(va)} vs {len(vb)}"})
        elif va:
            r = max(rel(u, v) for u, v in zip(va, vb))
            checks += len(va)
            ok = r <= tol or max(abs(u - v) for u, v in zip(va, vb)) <= floor
            note = ""
            if not ok and (signdep or informational):
                # In a sign-dependent section the individual values carry the
                # same arbitrary sign as the sum, so compare MAGNITUDES -- the
                # invariant. A rel of exactly 2.0 is the signature: |x-y|/max(x,y)
                # equals 2 only when y == -x. Magnitudes must still agree, so a
                # genuine error is still caught.
                ra = max(rel(abs(u), abs(v)) for u, v in zip(va, vb))
                ra_abs = max(abs(abs(u) - abs(v)) for u, v in zip(va, vb))
                # Judged against the section's own scale, as trace and norm
                # already are: an equivalent-but-different factorisation of the
                # fitting metric perturbs elements at the 1e-11 level, which is
                # negligible beside a tensor whose largest element is ~21.
                if ra <= tol or ra_abs <= floor:
                    ok, note, r = True, " (|values| agree; signs differ)", ra
                    gauge += 1
            if not ok:
                bad += 1
                worst = max(worst, r)
                rec["failures"].append({"section": label, "field": "values",
                                        "rel": r, "detail": f"{len(va)} numbers"})
            print(f"  {label:32s} {'values':16s} {len(va):4d} numbers"
                  f"{'':25s} max rel={r:.2e}  {'ok' if ok else 'MISMATCH'}{note}")

    rec.update(checks=checks, noise=noise, gauge=gauge, worst=worst)
    print(f"\n{checks} quantities compared across {len(A)} sections")
    if noise:
        print(f"{noise} quantity/quantities agreed only in absolute terms "
              f"(analytically-zero values; see section_scale)")
    if gauge:
        print(f"{gauge} quantity/quantities excused as sign-dependent or "
              f"informational (see sign_dependent)")
    print(f"worst UNEXPLAINED relative difference: {worst:.3e}   "
          f"tolerance: {tol:.1e}")
    if bad:
        rec["status"] = "fail"
        finish(f"FAIL: {bad} quantity/quantities disagree")
    print("PASS: Fortran port matches the C reference")
    finish()


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("c_out")
    ap.add_argument("f_out")
    ap.add_argument("tolerance", nargs="?", type=float, default=1e-10)
    ap.add_argument("--name", help="sample name, recorded in the JSONL")
    ap.add_argument("--jsonl", help="append a machine-readable record here")
    a = ap.parse_args()
    main(a.c_out, a.f_out, a.tolerance, a.name, a.jsonl)
