// cfg/dune/wct/job/sigproc.jsonnet
//
// WCT sub-graph (single anode):
//   FrameBoundarySource -> OmnibusSigProc -> FrameBoundarySink
//
// Signal processing (digits -> signals) for one anode of any DUNE detector.
// Component definitions live in parts.jsonnet; this file only composes them.
//
// TLA parameters: same as sim.jsonnet (source_name, sink_name, app_name,
//   detector, anode_index, service_prefix, variant).
//
// Required WCT plugins: WireCellPgraph, WireCellSigProc, WireCellAux

local g     = import "../lib/graph.jsonnet";
local parts = import "parts.jsonnet";

function(
    source_name    = "wcphlex_frame_source",
    sink_name      = "wcphlex_frame_sink",
    app_name       = "wcphlex_pgrapher",
    detector       = "pdhd",
    anode_index    = "0",
    service_prefix = "",
    variant        = "ideal",
)

local P = parts(detector, anode_index, service_prefix, variant);

local src = g.source({ type: "FrameBoundarySource", name: source_name, data: {} });
local snk = g.sink({   type: "FrameBoundarySink",   name: sink_name,   data: {} });

local graph = g.pipeline([src, g.filter(P.sigproc), snk]);

// Service components + SP filter instances (looked up by hard-coded C++ name).
local services = [P.dft, P.wires, P.fr, P.elec, P.anode]
                 + P.filter_response_comps + P.sp_filters;

g.application(graph, name=app_name, extra=services)
