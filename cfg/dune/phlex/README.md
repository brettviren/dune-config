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

## Geometry from GDML (no WCT wires file)

`gdml=default` (or `gdml=<file>`) makes the job read the detector's
LArSoft-convention GDML once per job instead of a WCT wires file: phlex-gdml's
`pgd_provider` makes the GDML a `job`-layer product, wire-cell-phlex's
`wcph_gdml_geometry` turns it into the wire schema (LArSoft channel numbers)
and the drift planes, and the WCT executor takes both as inputs beside its
event data and configures WCT on its first call.  `anode_indices=[...]` runs
several anodes (islands) in one job.

`dune/phlex/gdml.jsonnet` gives each detector's GDML (per variant) and the
LArSoft channel map and TPC sorter the transform ports; each reproduces the
detector's WCT wires file channel for channel (wire-cell-phlex
`gdml_wires_*` tests):

| detname | GDML (`default`)                | readout | sorter        | matches wires file          |
|---------|---------------------------------|---------|---------------|-----------------------------|
| pdhd    | protodunehd_v8_refactored       | apa     | apa           | protodunehd-wires-larsoft-v1 |
| pdvd    | protodunevd_v4_refactored       | crp     | cru60d-pdvd   | protodunevd-wires-larsoft-v3 |
| fdvd    | dunevd10kt_3view_30deg_v8_full10kt_ggd (v6: _v6_refactored) | crp | cru60d | fdvd-v8-fromgeo-pairtpc |

`gdml_readout`, `gdml_sorter`, `gdml_grouping` override them.  The WCT side of
the drift planes is per detector, `drift_planes` in
`dune/wct/detectors/<det>/detector.jsonnet` (FacadeDriftPlanes):

- pdhd: anode cut 9.52 mm from the collection plane (the first induction
  plane, as the file-mode faces).  The GDML's outer (cryostat wall side)
  TPCs are ~2.5 cm deep; a face whose drift is under 10 % of the detector's
  longest (wcph_gdml_geometry `min_drift_fraction`) is insensitive and
  FacadeDriftPlanes gives a null face for it, as the old Jsonnet faces lists
  did, and no xregion.  (The file-mode PDHD faces keep both faces active.)
- pdvd: per X. Ning's review of the PDVD config (one-sided CRP): anode cut at
  the CRP shield plane 16.4 mm from W, response plane 18.1 cm from W (the
  field response origin), cathode at |x| = 3 cm; the file-mode faces are the
  same planes.  MC `ctoffset` = 18.1 cm/v - 18.1 cm/(1.53 mm/us).

## Whole detector: shared services, one drift, hydra

Each anode is one WCT island (its own `WireCell::Main`), but the islands of a
job share what does not depend on the anode.  `dune/wct/job/parts.jsonnet`
names the DFT, field response, electronics response, plane impact responses,
wires file and filter responses by their content (a label and a hash of
their data), so islands that need the same service name the same WCT
instance and WCT configures it once (a later Main skips an identically
configured component).  Anodes, RNGs (seeds `[0,0,0,0,ident]`), noise
models and the sim/SP stages stay per anode.

`drift="job"` adds one `drift` module (`wcph_deposet_filter` running
`dune/wct/job/drift.jsonnet`) that drifts each event's depos once over all
drift regions; every island takes the drifted depos and keeps its anode's
(`DepoSetFilter`), as the art multi-sim drifts once ahead of its fanout.
`hydra=true` then lets an island whose anode has no depos skip sim and SP
(`DeposOrBust` + `FrameSync`, an empty frame).  Frames carry their event
number (`DepoTransform` `frame_ident: "deposet"`), and SP output is written
as separate `gauss` and `wiener` arrays.

```
phlexed -c dune/phlex/sp-job.jsonnet -A detname=fdvd -A variant=v8 -A sp_input=sim \
    -A in_file=depos.npz -A out_file=signals.npz --tla-code nevents=2 \
    -A gdml=dunevd10kt_3view_30deg_v8_full10kt_ggd.gdml \
    -A drift=job --tla-code hydra=true --tla-code anode_indices='std.range(0,319)'
```

FD-VD v8, 2 G4 muon events (the art multi-sim's): 320 islands in 24 s and
3.9 GB peak RSS, against 32 s and 3.7 GB for the art/LArSoft multi-sim (320
anodes, hydra) on the same events.  The memory is mostly the 320 AnodePlanes
(~11 MB each).  The lit anodes and their charge agree with the art job (see
topics/wcls-wires/envs/wcls/run/v8/compare-phlex.py in the xero area).

### All anodes in one WCT graph (`combine`), Pgrapher or TbbFlow

`combine=true` (with `drift="job"` and `anode_indices`) replaces the
per-anode islands and sinks by ONE executor module `wct` running
`dune/wct/job/multi-sim-sigproc.jsonnet` and one sink `sink` writing
`out_file`; the `drift` module stays separate.  The WCT graph is

```
DepoSetBoundarySource -> multifan DepoSetFanout(N)
  -> per anode k: DepoSetFilter -> [DeposOrBust ->] sim -> OmnibusSigProc [-> FrameSync]
                  -> Retagger (gauss -> gauss<k>, wiener -> wiener<k>)
-> multifan FrameFanin(N) -> Retagger (merge gauss\d+ -> gauss, wiener\d+ -> wiener)
-> FrameBoundarySink
```

The fans are `multifan.jsonnet` trees (no node over 10 ports, as TbbFlow
needs); every FrameFanin of the tree carries forward the per-anode tags of
its subtree.  Each branch has the components (names, configs, seeds) of the
drifted hydra island of its anode, and services are shared as between
islands.  FrameFanin takes the frame time from an input with traces (WCT
FrameFanin fix of 2026-11-13; an empty hydra frame has time 0).  On the 16
lit anodes of the 2 v8 muon events the merged frame equals the 16 islands'
frames channel for channel, with either engine and with 16 or 320 anodes.

`wct_app="TbbFlow"` runs every executor's WCT graph (drift, islands or the
combined graph) under TbbFlow instead of Pgrapher (adds the WireCellTbb
plugin and passes `app_type` to the WCT job).  FD-VD v8, 2 events, hydra,
one run each on a 64-core host (`phlexed -j 64`):

| anodes | layout   | engine   | wall  | peak RSS | CPU    |
|--------|----------|----------|-------|----------|--------|
| 16     | islands  | Pgrapher |  9.5 s | 4.6 GB  |  96 s  |
| 16     | islands  | TbbFlow  | 15.1 s | 3.7 GB  |  89 s  |
| 16     | combined | Pgrapher | 78.9 s | 1.0 GB  |  78 s  |
| 16     | combined | TbbFlow  | 15.0 s | 3.5 GB  |  87 s  |
| 320    | islands  | Pgrapher | 23.8 s | 3.9 GB  | 111 s  |
| 320    | islands  | TbbFlow  | 33.7 s | 3.4 GB  | 120 s  |
| 320    | combined | Pgrapher | 88.8 s | 2.1 GB  |  92 s  |
| 320    | combined | TbbFlow  | 23.5 s | 4.3 GB  | 105 s  |
