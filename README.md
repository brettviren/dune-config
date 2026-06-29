# dune-config

Standalone Jsonnet configuration for DUNE detector simulation and signal
processing, consumed by **phlex/phlexed** and **wire-cell-toolkit**.

This package ships **no compiled code** — only a tree of Jsonnet configuration
installed onto the phlex/WIRECELL runtime search path.  It is the porting/
re-organization target for `devel/wire-cell-phlex/cfg/dune/` and, later, for the
far-detector configs under `reference/dunereco/dunereco/DUNEWireCell/`.

Tracked by beads epic **ddm-4pz**.

## Two strictly-separate config domains

- `cfg/dune/phlex/` — phlex/phlexed job configuration. References (does not
  duplicate) the WCT job-config file it feeds.
- `cfg/dune/wct/` — wire-cell-toolkit configuration, factored into
  job-level (parameterized by a canonical `detname`) and detector-level
  (selected by `detname`, varied by `params.variant`) concerns.

## Layout

```
cfg/dune/                 import namespace root ("dune/...")
  smoke.jsonnet           placeholder for the smoke test
  wct/
    lib/                  schema + variant resolver + pgraph/compose helpers
    detectors/            per-detector descriptions (+ variant overlays)
    job/                  WCT subgraph builders (pnodes) + I/O-ends registries
  phlex/
    job/                  phlex workflow builders
test/
  smoke-workflow.jsonnet  ctest smoke (namespaced import resolves)
```

Each currently-empty directory has a `README.md` naming the beads task that
fills it.

## Settled design decisions (2026-06-29)

1. **Location**: `devel/dune-config` — a buildable/installable source package
   (like `wire-cell-phlex/cfg`), placed on the search path via the devel/
   superbuild and (later) `spack develop`.
2. **Composition**: the WCT `pgraph.jsonnet` pnode library
   (`pnode`/`intern`/`pipeline`/`fan.*`). `sim-sigproc = pg.pipeline([sim, sigproc])`.
3. **Variants**: one canonical `detname` plus a `variant` param selecting an
   overlay merged onto the base detector (`base + patch`), validated by a
   detector schema.

## Build & test

Built as part of the devel/ superbuild (auto-discovered by `project()` name):

```bash
cmake -S devel -B builds/devel -DCMAKE_PREFIX_PATH=<spack-view>
cmake --build builds/devel
ctest --test-dir builds/devel/dune_config   # dune_config_jsonnet_smoke
```

Standalone (config-only, no toolchain needed):

```bash
cmake -S devel/dune-config -B /tmp/dune-config-build
ctest --test-dir /tmp/dune-config-build --output-on-failure
```

The install drops the tree at `<prefix>/share/dune-config/cfg`; add that to
`WIRECELL_PATH` (and the phlex jsonnet search path) so `import "dune/..."`
resolves at runtime.

> Spack packaging (a recipe + `spack develop` entry) is tracked separately as
> beads **ddm-4pz.17**; for now the devel/ superbuild is the build route.
