# `dune/wct/lib/` — shared WCT-config libraries

Cross-cutting Jsonnet helpers consumed by detectors and job builders.

| File | Role | Beads |
|---|---|---|
| `graph.jsonnet` | Sub-graph composition over WCT's `pgraph.jsonnet` pnodes: `source`/`filter`/`sink`/`node` port-bearing constructors, `pipeline`/`fan` composition, and `application()` to finalize a closed graph into the `[…components…, Pgrapher]` sequence the executor expects. Shared service inodes referenced via `uses` are de-duplicated by `pg.uses()`. | ddm-4pz.2 |
| `schema.jsonnet` | Detector-description schema: structural defaults + `validate()` + `make(fields)`. Structure/types only — no physics values or units, so it imports nothing. | ddm-4pz.3 |
| `variant.jsonnet` | Variant overlays: `select(params)`, `apply(base, overlay)` (deep merge of detector-level fields), `patch_anodes(det, patches)` (per-anode patches by index). | ddm-4pz.3 |

The registry that ties detectors to canonical names lives one level up at
`dune/wct/detectors.jsonnet`.

## Quick reference

```jsonnet
// Compose + finalize a WCT sub-graph
local g = import "dune/wct/lib/graph.jsonnet";
local graph = g.pipeline([ g.source(src), g.filter(mid), g.sink(snk) ]);
g.application(graph, name="my_app", extra=det.sp_filters)   // -> WCT config array

// Build + validate a detector, then pick a variant
local schema  = import "dune/wct/lib/schema.jsonnet";
local variant = import "dune/wct/lib/variant.jsonnet";
local base = schema.make({ name:"demo", daq:{…}, lar:{…}, sim:{…},
                           response_plane:…, wires:{…}, anodes:[…], sp_filters:[] });
local det  = { ideal: base,
               real:  variant.patch_anodes(base, {"2": { elec:{ gain: 7.8 } }}) }
             [variant.select(params)];
```
