# `dune/wct/detectors/` — detector descriptions

One subdir per canonical detector (`pdhd/`, `pdvd/`, FD families …), each a
`function(params) -> detector-description` built on `dune/wct/lib/schema.jsonnet`.
Variants (ideal vs as-built, geometry phases) are overlays selected by
`params.variant`, not separate detectors. A `detectors.jsonnet` registry maps
canonical `detname -> function`.

Filled by beads **ddm-4pz.3** (registry/schema), **.4** (PDHD), **.5** (PDVD),
**.13** (PDHD real variant), **.14** (FD-HD), **.15** (FD-VD).

(Placeholder.)
