#!/usr/bin/env bash
#
# integration-run.sh -- ON-DEMAND phlex(ed) integration run of the dune-config
# stack (beads ddm-4pz.12).  NOT a default ctest: it needs the built phlex/WCT
# runtime (wcp_* modules), the WCT data files (reference/wire-cell-data), and a
# deposet input -- i.e. a full runtime env, and it reads reference/ (which the
# project rule keeps out of automated unit tests).
#
# It drives dune/phlex/sp-job.jsonnet with `phlexed` (CLI TLAs + jpath).
#
#   Stage A (sim path): deposets -> drift/sim/digitize -> frames NPZ.  This is
#     the live, asserted check -- it exercises the whole new phlex+WCT+detector
#     stack and MUST produce a non-trivial NPZ.
#   Stage B (full sim-sigproc): adds OmnibusSigProc and compares the output to a
#     reference NPZ.  Currently BLOCKED by a WCT OmnibusSigProc channel->wire
#     mapping crash (see ddm-4pz.12 notes / the linked blocker); reported, not
#     fatal, until that is fixed.
#
# Usage:
#   test/integration-run.sh [VIEW] [DEPOS_NPZ]
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)        # .../devel/dune-config/test
pkg=$(dirname "$here")
repo=$(cd "$pkg/../.." && pwd)
DC="$pkg/cfg"
WCP="$repo/devel/wire-cell-phlex/cfg"
VIEW=${1:-"$repo/extern/envs/xerosere/view"}
WCDATA="$repo/reference/wire-cell-data"
DEPOS=${2:-"$repo/devel/wire-cell-phlex/test/data/muon-depos.npz"}
OUTDIR=$(mktemp -d)
trap 'rm -rf "$OUTDIR"' EXIT

PHLEXED="$VIEW/bin/phlexed"
export PHLEX_PLUGIN_PATH="$VIEW/lib"
export WIRECELL_PATH="$DC:$WCP:$VIEW/share/wirecell:$WCDATA"
export LD_LIBRARY_PATH="$VIEW/lib:$VIEW/lib64:${LD_LIBRARY_PATH:-}"

for need in "$PHLEXED" "$DEPOS" "$WCDATA"; do
    [ -e "$need" ] || { echo "SKIP: missing $need (need a full runtime env)"; exit 77; }
done

run() {  # job-knobs... -> writes $OUTDIR/$1.npz
    local label=$1; shift
    "$PHLEXED" -c "$DC/dune/phlex/sp-job.jsonnet" \
        -A detname=pdhd -A in_file="$DEPOS" -A out_file="$OUTDIR/$label.npz" \
        --tla-code anode_index=0 --tla-code nevents=1 "$@"
}

echo "=== Stage A: sim path (deposets -> sim -> digits) ==="
# sim-only via the general builder (no OmnibusSigProc).
"$PHLEXED" -c "$DC/dune/phlex/workflow.jsonnet" \
    -A detname=pdhd -A wct_job=sim -A in_kind=deposet-file -A out_kind=frame-file \
    -A in_file="$DEPOS" -A out_file="$OUTDIR/sim.npz" \
    --tla-code anode_index=0 --tla-code nevents=1 \
    && [ -s "$OUTDIR/sim.npz" ] \
    && echo "  PASS: sim digits NPZ produced ($(stat -c%s "$OUTDIR/sim.npz") bytes)" \
    || { echo "  FAIL: sim path did not produce output"; exit 1; }

echo
echo "=== Stage B: full sim-sigproc + equivalence (combined == split) ==="
# Combined: deposets -> sim+SP in ONE executor.
run ss -A sp_input=sim 2>"$OUTDIR/ss.err" && [ -s "$OUTDIR/ss.npz" ] \
    || { echo "  FAIL: sim-sigproc did not produce output"; sed 's/^/    /' "$OUTDIR/ss.err" | tail -3; exit 1; }
echo "  PASS: sim-sigproc NPZ produced ($(stat -c%s "$OUTDIR/ss.npz") bytes)"
# Split: signal-process the Stage-A digits separately; must match the combined run
# (same fixed RNG seed -> identical digits -> identical signals).
"$PHLEXED" -c "$DC/dune/phlex/workflow.jsonnet" \
    -A detname=pdhd -A wct_job=sigproc -A in_kind=frame-file -A out_kind=frame-file \
    -A in_file="$OUTDIR/sim.npz" -A out_file="$OUTDIR/split.npz" \
    --tla-code anode_index=0 --tla-code nevents=1 2>/dev/null
# NOTE: run python with a CLEAN LD_LIBRARY_PATH -- the view's BLAS (needed by
# phlexed) shadows system numpy's and breaks its C-extensions otherwise.
if [ -s "$OUTDIR/split.npz" ] && env -u LD_LIBRARY_PATH python3 "$here/compare_frames_npz.py" \
        --max-diff 2 --max-ch-diff 1 "$OUTDIR/ss.npz" "$OUTDIR/split.npz" >/dev/null 2>&1; then
    echo "  PASS: combined sim-sigproc == split sim->sigproc (runtime equivalence)"
else
    echo "  FAIL: combined vs split sim-sigproc mismatch"; exit 1
fi

echo
echo "RESULT: full dune-config stack runs end-to-end via phlexed (sim, sigproc, sim-sigproc)."
