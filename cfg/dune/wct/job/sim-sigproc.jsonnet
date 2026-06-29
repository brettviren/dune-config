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
    g.filter(P.sigproc),
    snk,
]);

// Union of sim + sigproc service/helper components (de-duplicated by pg.uses()).
local services = [P.dft, P.rng, P.wires, P.fr, P.elec, P.anode]
                 + P.pirs + [P.drifter_comp, P.noise_model]
                 + P.filter_response_comps + P.sp_filters;

g.application(graph, name=app_name, extra=services)
