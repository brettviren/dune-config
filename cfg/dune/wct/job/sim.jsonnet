// cfg/dune/wct/job/sim.jsonnet
//
// WCT sub-graph (single anode): DepoSetBoundarySource -> DepoSetDrifter
//   -> DepoTransform -> Reframer -> AddNoise -> Digitizer -> FrameBoundarySink
//
// Full drift + electronics simulation for one anode of any DUNE detector.
// Component definitions live in parts.jsonnet; this file only composes them.
//
// TLA parameters:
//   sources        [{type,name}] boundary source inode(s)   (executor-injected)
//   sinks          [{type,name}] boundary sink inode(s)     (executor-injected)
//   app_name       instance name for the Pgrapher          (executor-injected)
//   detector       canonical detector name, e.g. "pdhd" / "pdvd"
//   anode_index    anode index into det.anodes[] (string, e.g. "0")
//   service_prefix prefix for WCT service component names
//   variant        detector variant overlay (default "ideal")
//
// Required WCT plugins: WireCellPgraph, WireCellGen, WireCellSigProc, WireCellAux

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
    geometry       = "file",      // "file" (wires file) or "phlex" (job-layer products)
)

local P = parts(detector, anode_index, service_prefix, variant, geometry);

// sim = the "sim" composite input end (deposet boundary + drift/sim/digitize)
// feeding a frame sink.
local input  = ends.inputs.sim(P, sources[0]);
local output = ends.outputs["frame-file"](P, sinks[0]);

local graph = g.pipeline(input.pnodes + output.pnodes);

g.application(graph, name=app_name)
