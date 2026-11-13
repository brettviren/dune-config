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
// TLA parameters: same as sim.jsonnet, plus (strings, as Phlex passes TLAs):
//   drifted  "yes": the input depos are already drifted over the whole
//            detector (job/drift.jsonnet, e.g. one Phlex "drift" module ahead
//            of the per-anode islands); the anode's depos are selected with a
//            DepoSetFilter instead of drifting them here.
//   hydra    "yes": an anode whose (filtered) depo set is empty skips sim and
//            sigproc and gives an empty frame (DeposOrBust + FrameSync), as
//            the art multi-sim's use_hydra.  Needs drifted "yes" (an undrifted
//            set is not filtered by anode).
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
    drifted        = "no",
    hydra          = "no",
    app_type       = "Pgrapher",   // WCT graph engine (the executor's wct_app)
)

local yes(x) = x == true || x == "yes" || x == "true";
local is_drifted = yes(drifted);
local use_hydra = yes(hydra);
assert !use_hydra || is_drifted : "sim-sigproc: hydra needs drifted depos (drifted=yes)";

local P = parts(detector, anode_index, service_prefix, variant, geometry);

local input  = ends.inputs["deposet-file"](P, sources[0]);
local work = {
    pnodes: ends.bodies.sim(P, drifted=is_drifted).pnodes + ends.bodies.sigproc(P).pnodes,
};
local output = ends.outputs["frame-file"](P, sinks[0]);

// With hydra the depo filter stays ahead of the switch, so DeposOrBust sees
// this anode's depos only.
local middle = if use_hydra then
    [work.pnodes[0]] + ends.bodies.hydra(P, { pnodes: work.pnodes[1:] }).pnodes
else work.pnodes;

local graph = g.pipeline(input.pnodes + middle + output.pnodes);

g.application(graph, name=app_name, type=app_type)
