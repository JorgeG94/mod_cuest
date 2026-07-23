#!/usr/bin/env python3
"""Compare the C reference and Fortran port fingerprints for a cuEST sample.

Parses numbers out of both outputs rather than diffing text, so the two are
allowed to differ in spacing and exponent formatting.
"""
import re, sys

NUM = r"[-+]?\d+\.\d+(?:[EeDd][-+]?\d+)?"

def parse(path):
    out, cur = {}, None
    for ln in open(path):
        m = re.search(r"matrix\s+(\S.*?)\s*$", ln)
        if m and "dimension" not in ln:
            cur = m.group(1).strip(); out[cur] = {"block": []}; continue
        if cur is None:
            continue
        for key, label in (("trace", "trace"), ("Frobenius norm", "fro"),
                           (r"max \|A-A\^T\|", "asym")):
            m = re.search(key + r"\s*:\s*(" + NUM + ")", ln)
            if m:
                out[cur][label] = float(m.group(1).replace("D", "E").replace("d", "e"))
        if re.match(r"\s*(?:[-+]?\d+\.\d+\s+)+$", ln):
            out[cur]["block"] += [float(x) for x in ln.split()]
    return out

def main(a, b, tol=1e-10):
    A, B = parse(a), parse(b)
    if not A or not B:
        sys.exit(f"could not parse fingerprints (C:{len(A)} F:{len(B)} matrices)")
    if set(A) != set(B):
        sys.exit(f"matrix sets differ:\n  C: {sorted(A)}\n  F: {sorted(B)}")
    worst, bad = 0.0, 0
    for name in sorted(A):
        for key in ("trace", "fro", "asym"):
            if key not in A[name] or key not in B[name]:
                continue
            x, y = A[name][key], B[name][key]
            r = abs(x - y) / max(abs(x), 1e-30)
            worst = max(worst, r)
            flag = "ok" if r <= tol else "MISMATCH"
            if r > tol:
                bad += 1
            print(f"  {name:26s} {key:6s}  C={x: .14e}  F={y: .14e}  rel={r:.2e}  {flag}")
        ba, bb = A[name]["block"], B[name]["block"]
        if len(ba) != len(bb):
            print(f"  {name}: block sizes differ ({len(ba)} vs {len(bb)})"); bad += 1
        else:
            r = max((abs(u - v) / max(abs(u), 1e-30) for u, v in zip(ba, bb)),
                    default=0.0)
            worst = max(worst, r)
            if r > tol:
                bad += 1
            print(f"  {name:26s} block   {len(ba)} values           "
                  f"      max rel={r:.2e}  {'ok' if r <= tol else 'MISMATCH'}")
    print(f"\nworst relative difference: {worst:.3e}   tolerance: {tol:.1e}")
    if bad:
        sys.exit(f"FAIL: {bad} quantity/quantities disagree")
    print("PASS: Fortran port matches the C reference")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
