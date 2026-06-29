# `dune/wct/job/` — WCT subgraph builders

`function(TLAs) -> pnode` builders that turn a resolved detector description
into a composable WCT subgraph (pnodes with declared in/out ports). `sim`,
`sigproc`, `splat`; `sim-sigproc` is `pg.pipeline([sim, sigproc])`. Swappable
input/output "ends" registries (`inputs.jsonnet`, `outputs.jsonnet`) live one
level up under `dune/wct/`.

Filled by beads **ddm-4pz.6** (subgraphs), **.7** (multi-anode fan),
**.8** (I/O ends), **.16** (NF / DNN-ROI).

(Placeholder.)
