// cfg/dune/wct/job/multi-sim-sigproc.jsonnet
//
// WCT sub-graph (several anodes in ONE graph):
//
//   DepoSetBoundarySource -> multifan DepoSetFanout(N)
//     -> per anode k: DepoSetFilter -> [hydra(] sim -> sigproc [)]
//                     -> Retagger (gauss -> gauss<k>, wiener -> wiener<k>)
//   -> multifan FrameFanin(N) -> Retagger (merge gauss<k> -> gauss, ...)
//   -> FrameBoundarySink
//
// The combined form of N sim-sigproc.jsonnet islands (each drifted="yes"): the
// input depos are already drifted over the whole detector (job/drift.jsonnet,
// one Phlex "drift" module), each branch keeps its anode's depos and runs the
// same pnodes as a sim-sigproc island, and the N signal-processed frames are
// merged into one frame for the event.  Like the art multi-sim, but with one
// output frame instead of one product per anode.
//
// Each branch renames its SP trace tags per anode (gauss<k>, wiener<k>), the
// fan-in carries these distinct tags forward, and a final Retagger merges them
// into "gauss" and "wiener" over every anode, so the frame is written and read
// like a single-island SP frame.  The fans are multifan trees (no fan node has
// more than 10 ports, the TbbFlow limit).  Shared services are shared as in
// separate islands (content-named in parts.jsonnet); per-anode state (anode,
// RNG, noise model, stages) is per branch, with the same names and seeds as
// the islands, so each anode's output matches its island's.
//
// TLA parameters (strings, as Phlex passes TLAs): as sim-sigproc.jsonnet but
//   anode_indices  comma-separated anode indices, eg "83,87,281" (an array is
//                  also accepted when compiled directly)
//   hydra          "yes": a branch whose anode has no depos skips sim and
//                  sigproc and gives an empty frame (DeposOrBust + FrameSync)
//   app_type       WCT graph engine, "Pgrapher" or "TbbFlow" (must match the
//                  executor's wct_app)
// (the depos are always taken as drifted; there is no "drifted" TLA).
//
// Required WCT plugins: WireCellPgraph, WireCellGen, WireCellSigProc, WireCellAux

local g     = import "../lib/graph.jsonnet";
local mf    = import "multifan.jsonnet";
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
    app_type       = "Pgrapher",
)

local yes(x) = x == true || x == "yes" || x == "true";
local use_hydra = yes(hydra);

local indices =
    if std.isArray(anode_indices) then [std.toString(i) for i in anode_indices]
    else [std.stripChars(s, " ") for s in std.split(anode_indices, ",")];
local N = std.length(indices);
assert N > 0 : "multi-sim-sigproc: no anode_indices";

local Ps = [parts(detector, i, service_prefix, variant, geometry) for i in indices];

local sp_tags = ["gauss", "wiener"];

// One anode's depos -> SP frame with its trace tags renamed to <tag><k>, as a
// sim-sigproc island with drifted="yes" plus the Retagger.
local branch(i, P) =
    local work = ends.bodies.sim(P, drifted=true).pnodes + ends.bodies.sigproc(P).pnodes;
    local middle = if use_hydra
        then [work[0]] + ends.bodies.hydra(P, { pnodes: work[1:] }).pnodes
        else work;
    local retag = g.filter({
        type: "Retagger",
        name: service_prefix + "retag_" + P.a.name,
        data: { tag_rules: [{
            frame: { ".*": "sigproc" },
            trace: { [t]: t + i for t in sp_tags },
        }] },
    });
    g.pipeline(middle + [retag], "branch_" + P.a.name);

local branches = [branch(indices[n], Ps[n]) for n in std.range(0, N - 1)];

local pfx = service_prefix;
local fanout = mf.fanout(pfx + "multi_fanout", "DepoSetFanout", N);

// Every fan-in node, leaf or inner, carries forward the per-anode tags of the
// anodes reached through each of its ports (FrameFanin drops tags without rules).
local fanin = mf.fanin(pfx + "multi_fanin", "FrameFanin", N, data=function(node) {
    tags: [],
    tag_rules: [{
        frame: { ".*": "sigproc" },
        trace: { [t + indices[p]]: t + indices[p] for p in ports for t in sp_tags },
    } for ports in node.ports],
});

local merge = g.filter({
    type: "Retagger",
    name: pfx + "multi_merge",
    data: { tag_rules: [{
        frame: { ".*": "sigproc" },
        merge: { [t + "\\d+"]: t for t in sp_tags },
    }] },
});

local multi = g.intern(
    innodes=[fanout], outnodes=[merge], centernodes=branches + [fanin],
    edges=[g.pg.edge(fanout, branches[n], n, 0) for n in std.range(0, N - 1)]
        + [g.pg.edge(branches[n], fanin, 0, n) for n in std.range(0, N - 1)]
        + [g.pg.edge(fanin, merge, 0, 0)],
    name="multi_sim_sigproc");

local graph = g.pipeline(
    ends.inputs["deposet-file"](Ps[0], sources[0]).pnodes
    + [multi]
    + ends.outputs["frame-file"](Ps[0], sinks[0]).pnodes);

g.application(graph, name=app_name, type=app_type)
