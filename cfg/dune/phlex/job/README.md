# `dune/phlex/job/` — phlex/phlexed workflow builders

`function(params, ...) -> phlex workflow` (driver/sources/modules). These select
a detector (`detname` + `variant`) and input/output kinds, and **reference** the
`dune/wct/job/*` config file they feed — the phlex and wct config domains stay
strictly separate, joined only by that filename reference.

Filled by beads **ddm-4pz.9** (workflow builders), **.10** (sim↔raw-DAQ input
swap), **.12** (integration test).

(Placeholder.)
