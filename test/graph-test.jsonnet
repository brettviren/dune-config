// test/graph-test.jsonnet
//
// Test of dune/wct/lib/graph.jsonnet composition (beads ddm-4pz.2).
// Imports graph.jsonnet which pulls in WCT's pgraph.jsonnet + wirecell.jsonnet,
// so it must run with BOTH the package cfg dir and the WCT share dir on the
// jsonnet path:  jsonnet -J cfg -J <prefix>/share/wirecell.

local g = import "dune/wct/lib/graph.jsonnet";

// A non-wired service inode, and a deeper service it depends on (via .uses).
local dft  = { type: "FftwDFT",   name: "dft",  data: {} };
local wires = { type: "WireSchemaFile", name: "wires", data: {} };
local anode = { type: "AnodePlane", name: "a", data: {}, uses: [wires] };

// Wired stage inodes declare their service deps via `.uses`.
local src = g.source({ type: "DepoSetBoundarySource", name: "src", data: {} });
local mid = g.filter({ type: "DepoTransform", name: "mid", data: {}, uses: [anode, dft] });
local snk = g.sink({   type: "FrameBoundarySink",      name: "snk", data: {} });

local graph = g.pipeline([src, mid, snk], name="demo");
local cfg   = g.application(graph, name="app");

// components: src, mid, snk (wired) + anode, wires, dft (services via uses) + Pgrapher
local types = [c.type for c in cfg];
assert std.length(cfg) == 7 : "expected 7 config entries, got " + std.length(cfg);

local appnode = cfg[std.length(cfg) - 1];
assert appnode.type == "Pgrapher" && appnode.name == "app"
       : "last entry must be the named Pgrapher";
assert std.length(appnode.data.edges) == 2
       : "pipeline of 3 must yield 2 edges, got " + std.length(appnode.data.edges);

// every service reached via .uses is present exactly once
assert std.length([c for c in cfg if c.type == "AnodePlane"]) == 1 : "anode present once";
assert std.length([c for c in cfg if c.type == "WireSchemaFile"]) == 1 : "wires present once";

// `.uses` is stripped from the emitted components (WCT never sees it)
assert std.all([!std.objectHas(c, "uses") for c in cfg]) : "uses must be pruned from output";

// TOPOLOGICAL ORDER: a service is emitted before any client that uses it.
local idx(t) = [i for i in std.range(0, std.length(cfg) - 1) if cfg[i].type == t][0];
assert idx("WireSchemaFile") < idx("AnodePlane") : "wires before anode (anode uses wires)";
assert idx("AnodePlane") < idx("DepoTransform") : "anode before its client (mid uses anode)";

// --- service sharing: one shared inode referenced by two stages ------------
local shared = { type: "FftwDFT", name: "shared_dft", data: {} };
local a2 = g.filter({ type: "Reframer",       name: "a2", data: {}, uses: [shared] });
local b2 = g.filter({ type: "OmnibusSigProc", name: "b2", data: {}, uses: [shared] });
local shared_cfg = g.application(g.pipeline([src, a2, b2, snk]));
assert std.length([c for c in shared_cfg if c.name == "shared_dft"]) == 1
       : "shared service must be de-duplicated to one instance";

{ ok: true }
