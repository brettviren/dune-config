// cfg/dune/wct/job/sim-sigproc.jsonnet
//
// WCT sub-graph (single anode): DepoSetBoundarySource -> DepoSetDrifter
//   -> DepoTransform -> Reframer -> AddNoise -> Digitizer -> OmnibusSigProc
//   -> FrameBoundarySink
//
// Combined drift simulation + signal processing.  This is just the sim pipeline
// with the sigproc stage appended -- NOT a re-declaration.  All service
// components are shared with (de-duplicated against) both stages via parts.jsonnet,
// so the combined graph cannot drift away from the standalone sim/sigproc jobs
// the way the old hand-written combined file did.
//
// TLA parameters: same as sim.jsonnet.
//
// Required WCT plugins: WireCellPgraph, WireCellGen, WireCellSigProc, WireCellAux

local g     = import "../lib/graph.jsonnet";
local ends  = import "../lib/ends.jsonnet";
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

// The "sim" input end (deposets -> frames) feeding the sigproc body: swapping
// ends.inputs.sim for ends.inputs["frame-file"]/["daq-hdf"] yields the plain
// sigproc job -- that is the SP-input swap (ddm-4pz.10).
local input  = ends.inputs.sim(P, source_name);
local body   = ends.bodies.sigproc(P);
local output = ends.outputs["frame-file"](P, sink_name);

local graph = g.pipeline(input.pnodes + body.pnodes + output.pnodes);

g.application(graph, name=app_name)
