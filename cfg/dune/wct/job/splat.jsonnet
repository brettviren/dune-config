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
local ends  = import "../lib/ends.jsonnet";
local parts = import "parts.jsonnet";

function(
    sources        = [ends.boundary.deposet_source],   // executor-injected
    sinks          = [ends.boundary.frame_sink],   // executor-injected
    app_name       = "wcphlex_pgrapher",
    detector       = "pdhd",
    anode_index    = "0",
    service_prefix = "",
    variant        = "ideal",
)

local P = parts(detector, anode_index, service_prefix, variant);

local input  = ends.inputs["deposet-file"](P, sources[0]);
local body   = ends.bodies.splat(P);
local output = ends.outputs["frame-file"](P, sinks[0]);

local graph = g.pipeline(input.pnodes + body.pnodes + output.pnodes);

g.application(graph, name=app_name)
