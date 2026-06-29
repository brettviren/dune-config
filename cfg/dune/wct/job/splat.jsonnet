// cfg/dune/wct/job/splat.jsonnet
//
// WCT sub-graph (single anode): DepoSetBoundarySource -> DepoSetDrifter
//   -> DepoFluxSplat -> Reframer -> FrameBoundarySink
//
// Drift + DepoFluxSplat ("true signal") for one anode -- the truth reference
// for comparison against sim+sigproc in the SPDIR workflow.
// Component definitions live in parts.jsonnet; this file only composes them.
//
// TLA parameters: same as sim.jsonnet.
//
// Required WCT plugins: WireCellPgraph, WireCellGen, WireCellAux

local g     = import "../lib/graph.jsonnet";
local parts = import "parts.jsonnet";

function(
    source_name    = "wcphlex_deposet_source",
    sink_name      = "wcphlex_frame_sink",
    app_name       = "wcphlex_pgrapher",
    detector       = "pdhd",
    anode_index    = "0",
    service_prefix = "",
    variant        = "ideal",
)

local P = parts(detector, anode_index, service_prefix, variant);

local src = g.source({ type: "DepoSetBoundarySource", name: source_name, data: {} });
local snk = g.sink({   type: "FrameBoundarySink",      name: sink_name,   data: {} });

local graph = g.pipeline([
    src,
    g.filter(P.setdrifter),
    g.filter(P.splat),
    g.filter(P.reframer),
    snk,
]);

// DepoFluxSplat needs no elec/pirs/noise.
local services = [P.dft, P.rng, P.wires, P.fr, P.anode, P.drifter_comp];

g.application(graph, name=app_name, extra=services)
