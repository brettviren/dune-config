// test/graph-test.jsonnet
//
// Test of dune/wct/lib/graph.jsonnet composition (beads ddm-4pz.2).
// Imports graph.jsonnet which pulls in WCT's pgraph.jsonnet + wirecell.jsonnet,
// so it must run with BOTH the package cfg dir and the WCT share dir on the
// jsonnet path:  jsonnet -J cfg -J <prefix>/share/wirecell.

local g = import "dune/wct/lib/graph.jsonnet";

// Synthetic inodes (real component types; data irrelevant to the test).
local src = g.source({ type: "DepoSetBoundarySource", name: "src", data: {} });
local mid = g.filter({ type: "DepoSetDrifter",        name: "mid", data: {} });
local snk = g.sink({   type: "FrameBoundarySink",      name: "snk", data: {} });

// --- linear composition + finalize -----------------------------------------
local graph = g.pipeline([src, mid, snk], name="demo");
local extra = [{ type: "LfFilter", name: "flt", data: {} }];   // registered, not wired
local cfg   = g.application(graph, name="app", extra=extra);

// components: src, mid, snk (3) + extra (1) + Pgrapher (1) = 5
assert std.length(cfg) == 5 : "expected 5 config entries, got " + std.length(cfg);

local appnode = cfg[std.length(cfg) - 1];
assert appnode.type == "Pgrapher" && appnode.name == "app"
       : "last entry must be the named Pgrapher";
assert std.length(appnode.data.edges) == 2
       : "pipeline of 3 must yield 2 edges, got " + std.length(appnode.data.edges);

// the un-wired extra component is present
assert std.length([c for c in cfg if c.type == "LfFilter"]) == 1
       : "extra component must be registered exactly once";

// --- service sharing: one shared inode referenced by two stages ------------
local svc = { type: "FftwDFT", name: "dft", data: {} };
local a   = g.filter({ type: "Reframer",      name: "a", data: {} }, uses=[svc]);
local b   = g.filter({ type: "OmnibusSigProc", name: "b", data: {} }, uses=[svc]);
local shared_cfg = g.application(g.pipeline([src, a, b, snk]));
local nsvc = std.length([c for c in shared_cfg if c.type == "FftwDFT"]);
assert nsvc == 1 : "shared service must be de-duplicated to one instance, got " + nsvc;

{ ok: true }
