// cfg/dune/wct/job/drift.jsonnet
//
// WCT sub-graph (whole detector): DepoSetBoundarySource -> DepoSetDrifter
//   -> DepoSetBoundarySink
//
// Drift every depo of an event once, over all drift regions of the detector,
// for per-anode islands that then take the drifted depos (sim-sigproc.jsonnet
// drifted="yes"), as the art multi-sim drifts once ahead of its fanout.
//
// TLA parameters: as sim.jsonnet; anode_index only selects which anode's
// parts object supplies the detector-wide components (any anode will do).
//
// Required WCT plugins: WireCellPgraph, WireCellGen, WireCellAux

local g     = import "../lib/graph.jsonnet";
local ends  = import "../lib/ends.jsonnet";
local parts = import "parts.jsonnet";

function(
    sources        = [ends.boundary.deposet_source],   // executor-injected
    sinks          = [ends.boundary.deposet_sink],     // executor-injected
    app_name       = "wcphlex_pgrapher",
    detector       = "pdhd",
    anode_index    = "0",
    service_prefix = "",
    variant        = "ideal",
    geometry       = "file",
    app_type       = "Pgrapher",   // WCT graph engine (the executor's wct_app)
)

local P = parts(detector, anode_index, service_prefix, variant, geometry);

local graph = g.pipeline(
    ends.inputs["deposet-file"](P, sources[0]).pnodes
    + ends.bodies.drift(P).pnodes
    + ends.outputs["deposet-file"](P, sinks[0]).pnodes);

g.application(graph, name=app_name, type=app_type)
