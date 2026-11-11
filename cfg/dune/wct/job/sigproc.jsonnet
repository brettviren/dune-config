// cfg/dune/wct/job/sigproc.jsonnet
//
// WCT sub-graph (single anode):
//   FrameBoundarySource -> OmnibusSigProc -> FrameBoundarySink
//
// Signal processing (digits -> signals) for one anode of any DUNE detector.
// Component definitions live in parts.jsonnet; this file only composes them.
//
// TLA parameters: same as sim.jsonnet (sources, sinks, app_name,
//   detector, anode_index, service_prefix, variant).
//
// Required WCT plugins: WireCellPgraph, WireCellSigProc, WireCellAux

local g     = import "../lib/graph.jsonnet";
local ends  = import "../lib/ends.jsonnet";
local parts = import "parts.jsonnet";

function(
    sources        = [ends.boundary.frame_source],   // executor-injected
    sinks          = [ends.boundary.frame_sink],   // executor-injected
    app_name       = "wcphlex_pgrapher",
    detector       = "pdhd",
    anode_index    = "0",
    service_prefix = "",
    variant        = "ideal",
)

local P = parts(detector, anode_index, service_prefix, variant);

local input  = ends.inputs["frame-file"](P, sources[0]);
local body   = ends.bodies.sigproc(P);
local output = ends.outputs["frame-file"](P, sinks[0]);

local graph = g.pipeline(input.pnodes + body.pnodes + output.pnodes);

g.application(graph, name=app_name)
