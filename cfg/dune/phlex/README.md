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

The executor `cpp` is selected from the source→sink product flow
(`deposet→frame` ⇒ `wcp_deposet_to_frame`, `frame→frame` ⇒ `wcp_frame_filter`).

## SP-input swap (ddm-4pz.10)

| SP input | `in_kind` | `wct_job` | status |
|---|---|---|---|
| simulation | `deposet-file` | `sim-sigproc` | live |
| frame file | `frame-file` | `sigproc` | live |
| raw DUNE-DAQ | `daq-hdf` | `sigproc` | **gated** (Phlex 0.3.0 + phlex DAQ source, ddm-3j8.1.6) |

A `daq-hdf` workflow assembles today but references a not-yet-built phlex source
module; running it awaits the gated work.

## TLA delivery

`phlex` itself does not yet support Jsonnet TLAs/search paths
([discussion](https://github.com/orgs/Framework-R-D/discussions/522)); use
`phlexed` (adds `PHLEXED_PATH` + TLAs) or pre-compile with `wcsonnet`/`jsonnet`.
See the top-level README.
