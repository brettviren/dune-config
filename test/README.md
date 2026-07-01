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
| `dune_config_pdhd_variant` | `pdhd-variant-test.jsonnet` | PDHD ideal-vs-real overlay (only APA0 field differs) |
| `dune_config_job` | `job-test.jsonnet` | job builder chains + de-dup |
| `dune_config_ends` | `ends-test.jsonnet` | I/O ends registry + SP-input swap (WCT level) |
| `dune_config_phlex` | `phlex-test.jsonnet` | phlex workflow builder (cfg-only) |
| `dune_config_sp_swap` | `sp-swap-test.jsonnet` | SP-input swap sim/frame/daq (cfg-only) |
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

## Live phlex(ed) integration run (ddm-4pz.12)

`test/integration-run.sh` drives `dune/phlex/sp-job.jsonnet` with `phlexed`
(CLI TLAs + jpath) against the built runtime + `reference/wire-cell-data`.
On-demand (needs the full runtime; reads `reference/`), not a default ctest.

- **Stage A (sim path)** — deposets → drift/sim/digitize → frames NPZ. Asserted
  (~21 MB digits NPZ); exercises the whole phlex+WCT+detector stack + data.
- **Stage B (full sim-sigproc + equivalence)** — runs combined sim-sigproc AND
  split sim→sigproc and asserts they are identical (same fixed RNG seed → same
  signals). Validates OmnibusSigProc end-to-end and the composition at runtime.

> Run the Python comparison with a CLEAN `LD_LIBRARY_PATH` — the Spack view's
> BLAS (needed by phlexed) shadows system numpy's and breaks it otherwise.

```bash
test/integration-run.sh [VIEW] [DEPOS_NPZ]
```

## The comparison tool

`compare_wct_configs.py A.json B.json` matches WCT components by `(type,name)`,
reports `ONLY_A`/`ONLY_B`/`DIFF`, and recurses into `data` with a configurable
float tolerance.  Options: `--skip-type`, `--skip-name`, `--float-tol`,
`--show-match`.
