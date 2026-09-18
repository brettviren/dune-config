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
scripts/                  named commands for "popular" workflows (see below)
  cfg/                    baked Jsonnet configs the scripts fill via TLAs
test/
  smoke-workflow.jsonnet  ctest smoke (namespaced import resolves)
```

Each currently-empty directory has a `README.md` naming the beads task that
fills it.

## Scripts

`scripts/` gives a **name** to an emerging set of common DUNE workflows so they
can be referred to, discovered, and run without re-deriving a command line.  A
script is typically a thin wrapper that runs **`phlexed`** on a baked-in Jsonnet
config (under `scripts/cfg/`) adjusted by options; some are fuller shell or
Snakemake workflows.  A detector-specific job takes the detector as an option
(guessed from the input when possible).

- [`daq-to-frame-file`](scripts/daq-to-frame-file) — read a DUNE DAQ HDF5 file
  and write a WCT frame file (`.npz`/`.tar`/`.tar.gz`/`.zip`) via the
  `dune-daq-phlex` source + WCT's `FrameFileSink`.

See [`scripts/README.md`](scripts/README.md) for conventions and the full list.

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

# Using

The `phlex` program currently [does not support Jsonnet TLAs nor search
paths](https://github.com/orgs/Framework-R-D/discussions/522).  The
configuration here is designed around providing TLAs, either to Phlex Jsonnet or
via Phlex Jsonnet to WCT Jsonnet.  Until `phlex` gets this support, there are
two options.

1. Use `phlexed` instead of `phlex` to use its added TLA and a search path
   feature (otherwise identical to `phlex`).  This searches `PHLEXED_PATH` in
   addition to paths given on `-J/--jpath` CLI args.

2. Use `wcsonnet` or bare `jsonnet` to compile Jsonnet to JSON, giving TLAs and
   using search paths.  Give resulting JSON file to `phlex`.
