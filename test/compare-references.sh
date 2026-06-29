#!/usr/bin/env bash
#
# compare-references.sh — ON-DEMAND cross-checks of dune-config WCT configs
# against external references.  NOT part of the default ctest suite, because the
# project rule (memory: reference-dir-no-dependency) forbids our packages from
# depending on reference/ at build or test time, and because the wire-cell-phlex
# cfg/dune source is slated for deprecation (beads ddm-4pz.18).  The permanent,
# self-contained regression guard is the golden-snapshot ctest (check-golden.sh).
#
# This script is the harness for the two correctness cross-checks of beads
# ddm-4pz.11.  Run it manually when validating the port or refreshing goldens.
#
# Usage:
#   test/compare-references.sh [WCT_SHARE]
#
# WCT_SHARE defaults to <repo>/extern/envs/xerosere/view/share/wirecell.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)          # .../devel/dune-config/test
pkg=$(dirname "$here")                        # .../devel/dune-config
repo=$(cd "$pkg/../.." && pwd)                # repo root
DC="$pkg/cfg"
WCP="$repo/devel/wire-cell-phlex/cfg"
DUNERECO="$repo/reference/dunereco/dunereco/DUNEWireCell"
WCT_SHARE=${1:-"$repo/extern/envs/xerosere/view/share/wirecell"}
CMP="$here/compare_wct_configs.py"

jn() { jsonnet -J "$1" -J "$WCT_SHARE" --tla-str detector="$3" --tla-str anode_index="$4" "$2"; }

fail=0

# --- Check 1: regression vs wire-cell-phlex cfg/dune (the port source) -------
# sim/sigproc/splat must be component-identical.  (sim-sigproc is intentionally
# NOT compared: the old combined file diverged from old sim+sigproc; ours is the
# unified composition — see ddm-4pz.6.)
echo "=== Check 1: dune-config vs wire-cell-phlex cfg/dune (exact) ==="
if [ -d "$WCP/dune" ]; then
  for spec in "sim pdhd 0" "sigproc pdhd 0" "splat pdhd 0" \
              "sim pdvd 0" "sigproc pdvd 0" "splat pdvd 0" \
              "sim pdvd 4" "sigproc pdvd 4"; do
    set -- $spec; job=$1 det=$2 ai=$3
    a=$(mktemp); b=$(mktemp)
    jn "$WCP" "$WCP/dune/wct/job/$job.jsonnet" "$det" "$ai" > "$a" 2>/dev/null
    jn "$DC"  "$DC/dune/wct/job/$job.jsonnet"  "$det" "$ai" > "$b" 2>/dev/null
    if python3 "$CMP" --float-tol 0 "$a" "$b" >/tmp/cr.out 2>&1; then
      echo "  PASS  $job $det/$ai"
    else
      echo "  FAIL  $job $det/$ai"; sed 's/^/      /' /tmp/cr.out; fail=1
    fi
    rm -f "$a" "$b"
  done
else
  echo "  SKIP  wire-cell-phlex cfg/dune not present ($WCP/dune)"
fi

# --- Check 2: reference matrix vs dunereco DUNEWireCell -----------------------
# dunereco configs are full art/wcls jobs with their own extVars and search
# paths; a meaningful comparison needs per-entry --skip-type/--skip-name and a
# float tolerance.  This is a documented MANUAL matrix (the original
# docs/dune-config.md also kept it manual / out of ctest).  We do not evaluate
# dunereco here to keep the no-reference-dependency rule intact for automation;
# the commands below are the prepared harness for an operator to run by hand.
echo
echo "=== Check 2: dunereco reference matrix (manual) ==="
if [ -d "$DUNERECO" ]; then
  echo "  dunereco present: $DUNERECO"
  echo "  Prepared comparisons (run by hand; add --skip-type/--skip-name for art/wcls + NF nodes):"
  cat <<EOF
    # PDHD sim:     dunereco pdhd/wct-sim-check.jsonnet      vs  cfg/dune/wct/job/sim.jsonnet     (pdhd,0)
    # PDHD nf-sp:   dunereco pdhd/wcls-nf-sp.jsonnet         vs  cfg/dune/wct/job/sigproc.jsonnet (pdhd,0)  [skip NF + art nodes]
    # PDVD sim:     dunereco protodunevd/wct-sim-check.jsonnet vs cfg/dune/wct/job/sim.jsonnet    (pdvd,0)
    # Tool: python3 $CMP --float-tol 1e-6 --skip-type <art/wcls types> A.json B.json
EOF
else
  echo "  SKIP  reference/dunereco not present"
fi

echo
if [ "$fail" -eq 0 ]; then echo "RESULT: automated checks PASS"; else echo "RESULT: automated checks FAIL"; fi
exit $fail
