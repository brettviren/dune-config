// cfg/dune/wct/job/multi-sim-sigproc.jsonnet
//
// WCT sub-graph (several anodes in ONE graph):
//
//   DepoSetBoundarySource -> DepoSetFanout(N)
//     -> per anode: DepoSetFilter -> [hydra(] sim -> sigproc [)]
//   -> FrameFanin(N) -> FrameBoundarySink
//
// The combined form of N sim-sigproc.jsonnet islands (each drifted="yes"): the
// input depos are already drifted over the whole detector (job/drift.jsonnet,
// one Phlex "drift" module), each branch keeps its anode's depos and runs the
// same pnodes as a sim-sigproc island, and the N signal-processed frames are
// merged into one frame for the event.  Like the art multi-sim, but with one
// output frame instead of one product per anode.
//
// The merged frame keeps the "gauss" and "wiener" trace tags (each covering the
// traces of every anode; FrameFanin merges same-named output tags) so it is
// written and read like a single-island SP frame.  Shared services are shared
// as in separate islands (content-named in parts.jsonnet); per-anode state
// (anode, RNG, noise model, stages) is per branch, with the same names and
// seeds as the islands, so each anode's output matches its island's.
//
// TLA parameters (strings, as Phlex passes TLAs): as sim-sigproc.jsonnet but
//   anode_indices  comma-separated anode indices, eg "83,87,281" (an array is
//                  also accepted when compiled directly)
//   hydra          "yes": a branch whose anode has no depos skips sim and
//                  sigproc and gives an empty frame (DeposOrBust + FrameSync)
// (the depos are always taken as drifted; there is no "drifted" TLA).
//
// Required WCT plugins: WireCellPgraph, WireCellGen, WireCellSigProc, WireCellAux

local g     = import "../lib/graph.jsonnet";
local ends  = import "../lib/ends.jsonnet";
local parts = import "parts.jsonnet";

function(
    sources        = [ends.boundary.deposet_source],   // executor-injected
    sinks          = [ends.boundary.frame_sink],       // executor-injected
    app_name       = "wcphlex_pgrapher",
    detector       = "pdhd",
    anode_indices  = "0",
    service_prefix = "",
    variant        = "ideal",
    geometry       = "file",
    hydra          = "no",
)

local yes(x) = x == true || x == "yes" || x == "true";
local use_hydra = yes(hydra);

local indices =
    if std.isArray(anode_indices) then [std.toString(i) for i in anode_indices]
    else [std.stripChars(s, " ") for s in std.split(anode_indices, ",")];
local N = std.length(indices);
assert N > 0 : "multi-sim-sigproc: no anode_indices";

local Ps = [parts(detector, i, service_prefix, variant, geometry) for i in indices];

// One anode's depos -> SP frame, as a sim-sigproc island with drifted="yes".
local branch(P) =
    local work = ends.bodies.sim(P, drifted=true).pnodes + ends.bodies.sigproc(P).pnodes;
    local middle = if use_hydra
        then [work[0]] + ends.bodies.hydra(P, { pnodes: work[1:] }).pnodes
        else work;
    g.pipeline(middle, "branch_" + P.a.name);

local branches = [branch(P) for P in Ps];

local pfx = service_prefix;
local fanout = g.node({
    type: "DepoSetFanout",
    name: pfx + "multi_fanout",
    data: { multiplicity: N },
}, 1, N);

// Each port's SP trace tags pass through under their own names; FrameFanin
// merges the N "gauss" (and "wiener") into one tag over all traces.
local sp_tags = ["gauss", "wiener"];
local fanin = g.node({
    type: "FrameFanin",
    name: pfx + "multi_fanin",
    data: {
        multiplicity: N,
        tags: [],
        tag_rules: [{
            frame: { ".*": "sigproc" },
            trace: { [t]: t for t in sp_tags },
        } for n in std.range(0, N - 1)],
    },
}, N, 1);

local multi = g.intern(
    innodes=[fanout], outnodes=[fanin], centernodes=branches,
    edges=[g.pg.edge(fanout, branches[n], n, 0) for n in std.range(0, N - 1)]
        + [g.pg.edge(branches[n], fanin, 0, n) for n in std.range(0, N - 1)],
    name="multi_sim_sigproc");

local graph = g.pipeline(
    ends.inputs["deposet-file"](Ps[0], sources[0]).pnodes
    + [multi]
    + ends.outputs["frame-file"](Ps[0], sinks[0]).pnodes);

g.application(graph, name=app_name)
