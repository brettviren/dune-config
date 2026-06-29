# dune-config tests

All tests evaluate Jsonnet (no compiled code).  Those that import
`wirecell.jsonnet` (everything except the smoke and schema/variant tests) need
the WCT jsonnet share dir on the path; CMake discovers it from
`CMAKE_PREFIX_PATH` and skips those tests if absent.

| ctest | File | Checks |
|---|---|---|
| `dune_config_jsonnet_smoke` | `smoke-workflow.jsonnet` | `dune/` namespace resolves |
| `dune_config_schema_variant` | `schema-variant-test.jsonnet` | schema defaults/validate + variant overlays |
| `dune_config_graph` | `graph-test.jsonnet` | pnode composition + service de-dup |
| `dune_config_pdhd` / `_pdvd` | `pdhd-test.jsonnet` / `pdvd-test.jsonnet` | detector ports |
| `dune_config_job` | `job-test.jsonnet` | job builder chains + de-dup |
| `dune_config_parity_<det>_<job>_a<ai>` | golden + `check-golden.sh` | **WCT-config parity regression** |

## WCT-config parity (beads ddm-4pz.11)

Two correctness concerns, handled separately to respect the project rule that
our packages must not depend on `reference/` (or, by extension, the
to-be-deprecated wire-cell-phlex `cfg/dune`) at automated-test time.

### 1. Regression — permanent, self-contained (in ctest)

`test/golden/<det>-<job>-a<ai>.json` are committed snapshots of each job
sub-graph.  `check-golden.sh` re-evaluates the config and compares it
component-by-component (exact, `--float-tol 0`) to the golden via
`compare_wct_configs.py`.  No dependency on any other package.

**Refresh goldens** after an intentional config change:

```bash
WCT=extern/envs/xerosere/view/share/wirecell      # or any prefix with share/wirecell
for spec in "sim pdhd 0" "sigproc pdhd 0" "sim-sigproc pdhd 0" "splat pdhd 0" \
            "sim pdvd 0" "sigproc pdvd 0" "sim-sigproc pdvd 0" "splat pdvd 0" \
            "sim pdvd 4" "sigproc pdvd 4"; do
  set -- $spec
  jsonnet -J cfg -J "$WCT" --tla-str detector=$2 --tla-str anode_index=$3 \
      cfg/dune/wct/job/$1.jsonnet > test/golden/$2-$1-a$3.json
done
```

### 2. Cross-checks — on demand (NOT in ctest)

`test/compare-references.sh` compares dune-config against external references:

- **vs wire-cell-phlex `cfg/dune`** (the port source): `sim`/`sigproc`/`splat`
  must be component-identical.  `sim-sigproc` is intentionally excluded — the
  old combined file had diverged from old `sim`+`sigproc`; ours is the unified
  composition (ddm-4pz.6).  Verified PASS for pdhd/0, pdvd/0, pdvd/4.
- **vs dunereco `DUNEWireCell`**: a documented manual matrix (full art/wcls jobs
  need per-entry `--skip-type/--skip-name` + float tolerance).  The script
  prints the prepared commands; it does not evaluate dunereco automatically.

```bash
test/compare-references.sh [WCT_SHARE]
```

## The comparison tool

`compare_wct_configs.py A.json B.json` matches WCT components by `(type,name)`,
reports `ONLY_A`/`ONLY_B`/`DIFF`, and recurses into `data` with a configurable
float tolerance.  Options: `--skip-type`, `--skip-name`, `--float-tol`,
`--show-match`.
