# `dune/phlex/` — phlex/phlexed workflow configuration

The phlex-layer mirror of the WCT I/O ends.  Strictly separate from the WCT
config domain: these builders only **reference** a `dune/wct/job/*` config by
filename and pass the detector/variant/anode as TLAs.

| File | Role | Beads |
|---|---|---|
| `sources.jsonnet` | phlex source modules keyed by input kind (`deposet-file`, `frame-file`, `daq-hdf` stub) | ddm-4pz.9 |
| `sinks.jsonnet` | phlex sink modules keyed by output kind (`frame-file`, `deposet-file`) | ddm-4pz.9 |
| `workflow.jsonnet` | parameterized workflow builder `workflow(detname, wct_job, in_kind, out_kind, …)` | ddm-4pz.9 |

## Builder

```jsonnet
local workflow = import "dune/phlex/workflow.jsonnet";

// signal processing fed by simulation (deposets -> drift/sim -> SP -> frames)
workflow(detname="pdhd", wct_job="sim-sigproc",
         in_kind="deposet-file", out_kind="frame-file",
         in_file="depos.npz", out_file="frames.npz", variant="ideal")

// signal processing fed by a frame file (frames -> SP -> frames)
workflow(detname="pdhd", wct_job="sigproc",
         in_kind="frame-file", in_file="digits.npz", out_file="signals.npz")
```

Modules are wire-cell-phlex shape executors: sources `wcph_<type>_source`,
sinks `wcph_<type>_sink`, and the executor `cpp` selected from the source→sink
product flow (`deposet→frame` ⇒ `wcph_deposet_to_frame`, `frame→frame` ⇒
`wcph_frame_filter`, which registers node `wcph_frame_to_frame`).  Each module
names its products with `inputs`/`outputs` arrays of `{creator, layer, suffix}`:
a source's output creator is `input`; a transform's output creator is its own
module label (`wct`), so the sink's input is `{creator: "wct", layer: "event",
suffix: <product>}`.

The executor injects the boundary nodes into the WCT job as the code TLAs
`sources` and `sinks` (arrays of `{type, name}`) and the Pgrapher name as
`app_name`; the `dune/wct/job/*` functions take those, with defaults from
`dune/wct/lib/ends.jsonnet` `boundary` for standalone compiles.

Run, e.g. (2026-11-11: pdhd, fdvd anodes 0 and 200 run, rc 0):

```bash
phlexed -c dune/phlex/sp-job.jsonnet -A detname=fdvd -A sp_input=sim \
    -A in_file=depos.npz -A out_file=signals.npz --tla-code anode_index=0
```

with `PHLEX_PLUGIN_PATH` holding the `libwcph_*` modules, `PHLEXED_PATH` this
`cfg/`, and `WIRECELL_PATH` this `cfg/`, wire-cell-phlex's `cfg/` and the WCT
data.

## SP-input swap (ddm-4pz.10)

| SP input | `in_kind` | `wct_job` | status |
|---|---|---|---|
| simulation | `deposet-file` | `sim-sigproc` | live |
| frame file | `frame-file` | `sigproc` | live |
| raw DUNE-DAQ | `daq-hdf` | `sigproc` | **gated** |

A `daq-hdf` workflow assembles but does not run: the DAQ chain also needs the
`dune_daq_phlex_driver` and the `wire_cell_phlex_arrow_from_arrow` adapter (see
`scripts/cfg/daq-to-frame-file.jsonnet`, which runs), which the workflow
builder cannot yet add.

## TLA delivery

`phlex` itself does not yet support Jsonnet TLAs/search paths
([discussion](https://github.com/orgs/Framework-R-D/discussions/522)); use
`phlexed` (adds `PHLEXED_PATH` + TLAs) or pre-compile with `wcsonnet`/`jsonnet`.
See the top-level README.
