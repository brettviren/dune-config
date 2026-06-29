// cfg/dune/wct/job/sim.jsonnet
//
// WCT sub-graph (single anode): DepoSetBoundarySource -> DepoSetDrifter
//   -> DepoTransform -> Reframer -> AddNoise -> Digitizer -> FrameBoundarySink
//
// Full drift + electronics simulation for one anode of any DUNE detector.
// Component definitions live in parts.jsonnet; this file only composes them.
//
// TLA parameters:
//   source_name    instance name for DepoSetBoundarySource (executor-injected)
//   sink_name      instance name for FrameBoundarySink     (executor-injected)
//   app_name       instance name for the Pgrapher          (executor-injected)
//   detector       canonical detector name, e.g. "pdhd" / "pdvd"
//   anode_index    anode index into det.anodes[] (string, e.g. "0")
//   service_prefix prefix for WCT service component names
//   variant        detector variant overlay (default "ideal")
//
// Required WCT plugins: WireCellPgraph, WireCellGen, WireCellSigProc, WireCellAux

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
    g.filter(P.transform),
    g.filter(P.reframer),
    g.filter(P.addnoise),
    g.filter(P.digitizer),
    snk,
]);

// Service/helper components referenced by name but not wired as graph nodes.
local services = [P.dft, P.rng, P.wires, P.fr, P.elec, P.anode]
                 + P.pirs + [P.drifter_comp, P.noise_model];

g.application(graph, name=app_name, extra=services)
