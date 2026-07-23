#!/usr/bin/env python3
"""Render a run report from the records run_all.sh collects.

    report.py <build_dir> [-o REPORT.md]

Reads <build_dir>/results.jsonl -- one JSON object per example run and per
port-vs-reference comparison -- and writes a Markdown report next to it.

The point is that a failure should be readable without re-running anything:
which sample, which quantity, what the two values were, and where the captured
output is. A bare list of failing names sends you spelunking; this does not.
"""
import json
import os
import sys


def load(path):
    recs = []
    if not os.path.exists(path):
        return recs
    for ln in open(path):
        ln = ln.strip()
        if not ln:
            continue
        try:
            recs.append(json.loads(ln))
        except json.JSONDecodeError:
            pass                      # a truncated final line, e.g. after ^C
    return recs


def fmt_secs(s):
    try:
        return f"{float(s):.2f}s"
    except (TypeError, ValueError):
        return "-"


def main(build_dir, out=None):
    recs = load(os.path.join(build_dir, "results.jsonl"))
    if not recs:
        sys.exit(f"no records in {build_dir}/results.jsonl")
    out = out or os.path.join(build_dir, "REPORT.md")

    env = next((r for r in recs if r.get("kind") == "env"), {})
    runs = [r for r in recs if r.get("kind") == "run"]
    cmps = [r for r in recs if r.get("kind") == "compare"]

    L = []
    w = L.append
    w("# cuEST Fortran examples — run report")
    w("")
    if env:
        w("| | |")
        w("|---|---|")
        for k in ("date", "host", "gpu", "compute_cap", "cuda", "compiler",
                  "build_dir"):
            if env.get(k):
                w(f"| {k.replace('_', ' ')} | `{env[k]}` |")
        w("")

    try:
        cap = int(str(env.get("compute_cap", "")).strip() or 0)
    except ValueError:
        cap = 0
    if cap and cap < 80:
        w(f"> **This GPU (sm_{cap}) cannot run cuEST.** It ships device code for")
        w("> sm_80 and newer, so every sample aborts at `cuestCreate` with")
        w("> `CUEST_STATUS_UNSUPPORTED_ARCHITECTURE`. The failures below are that,")
        w("> not port defects. Re-run on an A100 or H100.")
        w("")

    run_ok = sum(1 for r in runs if r["status"] == "pass")
    cmp_ok = sum(1 for r in cmps if r["status"] == "pass")
    w("## Summary")
    w("")
    w(f"- examples run: **{run_ok}/{len(runs)}** exited cleanly")
    w(f"- compared against the C reference: **{cmp_ok}/{len(cmps)}** match")
    tot = sum(r.get("checks", 0) for r in cmps)
    noise = sum(r.get("noise", 0) for r in cmps)
    gauge = sum(r.get("gauge", 0) for r in cmps)
    w(f"- quantities compared: **{tot}**"
      + (f", of which {noise} agreed only in absolute terms (analytically zero)"
         if noise else ""))
    if gauge:
        w(f"- excused as sign-dependent or informational: **{gauge}** "
          f"(quantities the C reference does not reproduce against itself)")
    worst = max((r.get("worst", 0.0) for r in cmps), default=0.0)
    w(f"- worst unexplained relative difference: **{worst:.3e}**")
    w("")

    # ---- the table -------------------------------------------------------
    w("## Per sample")
    w("")
    w("| sample | ran | compared | quantities | worst rel |")
    w("|---|---|---|---:|---:|")
    by_name = {}
    for r in runs:
        by_name.setdefault(r["name"], {})["run"] = r
    for r in cmps:
        by_name.setdefault(r["name"], {})["cmp"] = r
    for name in sorted(by_name):
        e = by_name[name]
        r, c = e.get("run"), e.get("cmp")
        rs = {"pass": "ok", "fail": "**FAIL**", "skip": "skip"}.get(
            (r or {}).get("status"), "-")
        cs = {"pass": "ok", "fail": "**FAIL**"}.get((c or {}).get("status"), "-")
        q = c.get("checks", "-") if c else "-"
        wr = f"{c['worst']:.1e}" if c and c.get("worst") else ("0" if c else "-")
        w(f"| `{name}` | {rs} | {cs} | {q} | {wr} |")
    w("")

    # ---- failures, in detail --------------------------------------------
    bad_runs = [r for r in runs if r["status"] == "fail"]
    bad_cmps = [r for r in cmps if r["status"] == "fail"]
    if not bad_runs and not bad_cmps:
        w("## Failures")
        w("")
        w("None. Every example ran and every compared quantity matched the C")
        w("reference within tolerance.")
    else:
        w("## Failures")
        w("")
        for r in bad_runs:
            w(f"### `{r['name']}` — did not run")
            w("")
            w(f"Exited non-zero{'; ' + r['detail'] if r.get('detail') else ''}.")
            w("")
        for c in bad_cmps:
            w(f"### `{c['name']}` — disagrees with the C reference")
            w("")
            if c.get("failures"):
                w("| section | quantity | C | Fortran | rel |")
                w("|---|---|---|---|---:|")
                for f in c["failures"][:40]:
                    cv = f"`{f['c']:.9e}`" if "c" in f else "-"
                    fv = f"`{f['f']:.9e}`" if "f" in f else "-"
                    rl = f"{f['rel']:.2e}" if "rel" in f else f.get("detail", "-")
                    w(f"| {f.get('section', '-')} | {f.get('field', '-')} "
                      f"| {cv} | {fv} | {rl} |")
                if len(c["failures"]) > 40:
                    w("")
                    w(f"...and {len(c['failures']) - 40} more.")
            w("")
            w(f"Captured output: `{c['name']}.c.out` and `{c['name']}.f.out` "
              f"in the build directory.")
            w("")

    w("---")
    w("")
    w("Reading a disagreement: every port reports its *inputs* (`D`, `Cocc`,")
    w("`Cleft`/`Cright`) as their own sections. If an input section differs,")
    w("the synthetic-density RNG diverged and the rest follows from that; if")
    w("the inputs match and a result does not, the difference is in the cuEST")
    w("call sequence. `sum |a_i|` is invariant under sign flips while `sum` is")
    w("not, so agreement in norm and L1 but not in sum means the same values")
    w("with some signs differing. For the DF MO tensors that is a sign")
    w("convention in the fitting metric, not an error: two runs of the")
    w("unmodified C reference disagree with each other on that sum while their")
    w("norms are bit-identical, so it is excused rather than compared.")

    open(out, "w").write("\n".join(L) + "\n")
    print(f"wrote {out}")
    return 1 if (bad_runs or bad_cmps) else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    o = None
    if "-o" in sys.argv:
        i = sys.argv.index("-o")
        o = sys.argv[i + 1]
    sys.exit(main(sys.argv[1], o))
