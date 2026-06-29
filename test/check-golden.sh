#!/usr/bin/env bash
#
# check-golden.sh — regression guard for a single WCT job config.
#
# Re-evaluates a dune-config WCT job sub-graph and compares it, component-by-
# component (order-independent, exact), against a committed golden snapshot.
# Self-contained: depends only on jsonnet, the WCT jsonnet share dir, python3,
# and the golden file in this repo — NOT on wire-cell-phlex or reference/.
#
# Usage:
#   check-golden.sh JSONNET CFG_DIR WCT_SHARE COMPARE_PY GOLDEN JOB DET ANODE
#
# Regenerate goldens (after an intentional config change), e.g.:
#   jsonnet -J cfg -J <share/wirecell> --tla-str detector=pdhd --tla-str anode_index=0 \
#       cfg/dune/wct/job/sim.jsonnet > test/golden/pdhd-sim-a0.json
set -euo pipefail

JSONNET=$1; CFG=$2; WCT_SHARE=$3; COMPARE=$4; GOLDEN=$5; JOB=$6; DET=$7; AI=$8

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

"$JSONNET" -J "$CFG" -J "$WCT_SHARE" \
    --tla-str detector="$DET" --tla-str anode_index="$AI" \
    "$CFG/dune/wct/job/$JOB.jsonnet" > "$tmp"

# Exact regression match: no float tolerance, no skips.
python3 "$COMPARE" --float-tol 0 "$GOLDEN" "$tmp"
