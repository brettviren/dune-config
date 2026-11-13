// test/job-test.jsonnet
//
// Composition + service-sharing tests for the WCT job builders (beads ddm-4pz.6).
// Run with:  jsonnet -J cfg -J <prefix>/share/wirecell.
//
// (Content parity of sim/sigproc/splat vs the wire-cell-phlex originals was
// verified during this task; the formal parity harness is beads ddm-4pz.11.)

local sim         = import "dune/wct/job/sim.jsonnet";
local sigproc     = import "dune/wct/job/sigproc.jsonnet";
local sim_sigproc = import "dune/wct/job/sim-sigproc.jsonnet";
local splat       = import "dune/wct/job/splat.jsonnet";

local cfg_sim   = sim(detector="pdhd", anode_index="0");
local cfg_sigp  = sigproc(detector="pdhd", anode_index="0");
local cfg_ss    = sim_sigproc(detector="pdhd", anode_index="0");
local cfg_splat = splat(detector="pdhd", anode_index="0");

local count(cfg, t) = std.length([c for c in cfg if c.type == t]);
local appnode(cfg)  = [c for c in cfg if c.type == "Pgrapher"][0];
local chain(cfg)    = [
    std.split(e.tail.node, ":")[0] + "->" + std.split(e.head.node, ":")[0]
    for e in appnode(cfg).data.edges
];

// --- sim: drift+digitize, no sigproc ---------------------------------------
assert count(cfg_sim, "Digitizer") == 1 : "sim has a Digitizer";
assert count(cfg_sim, "OmnibusSigProc") == 0 : "sim has no OmnibusSigProc";
assert chain(cfg_sim) == [
    "DepoSetBoundarySource->DepoSetDrifter",
    "DepoSetDrifter->DepoTransform",
    "DepoTransform->Reframer",
    "Reframer->AddNoise",
    "AddNoise->Digitizer",
    "Digitizer->FrameBoundarySink",
] : "sim chain";

// --- sigproc: frame in, signals out ----------------------------------------
assert count(cfg_sigp, "OmnibusSigProc") == 1 : "sigproc has OmnibusSigProc";
assert chain(cfg_sigp) == [
    "FrameBoundarySource->OmnibusSigProc",
    "OmnibusSigProc->FrameBoundarySink",
] : "sigproc chain";

// --- sim-sigproc: the two composed, services shared ------------------------
assert chain(cfg_ss) == [
    "DepoSetBoundarySource->DepoSetDrifter",
    "DepoSetDrifter->DepoTransform",
    "DepoTransform->Reframer",
    "Reframer->AddNoise",
    "AddNoise->Digitizer",
    "Digitizer->OmnibusSigProc",
    "OmnibusSigProc->FrameBoundarySink",
] : "sim-sigproc chain is sim with sigproc appended";
// service sharing: each shared service appears exactly once despite being
// referenced by both the sim and sigproc stages.
assert count(cfg_ss, "FftwDFT") == 1 : "shared DFT de-duplicated";
assert count(cfg_ss, "AnodePlane") == 1 : "shared AnodePlane de-duplicated";
assert count(cfg_ss, "FieldResponse") == 1 : "shared FieldResponse de-duplicated";
assert count(cfg_ss, "Digitizer") == 1 && count(cfg_ss, "OmnibusSigProc") == 1
       : "sim-sigproc has both Digitizer and OmnibusSigProc";

// --- configuration ORDER: services before their consumers ------------------
// WCT configures components in array order; OmnibusSigProc walks the AnodePlane
// in its own configure() to size arrays, so the anode MUST appear first.  This
// is invisible to the (order-independent) parity goldens, so guard it here.
local idx(cfg, t) = [i for i in std.range(0, std.length(cfg) - 1) if cfg[i].type == t][0];
assert idx(cfg_sigp, "AnodePlane") < idx(cfg_sigp, "OmnibusSigProc")
       : "sigproc: AnodePlane must be emitted before OmnibusSigProc";
assert idx(cfg_ss, "AnodePlane") < idx(cfg_ss, "OmnibusSigProc")
       : "sim-sigproc: AnodePlane must be emitted before OmnibusSigProc";

// --- splat: truth reference, no elec/digitize/sigproc ----------------------
assert count(cfg_splat, "DepoFluxSplat") == 1 : "splat has DepoFluxSplat";
assert count(cfg_splat, "Digitizer") == 0 : "splat has no Digitizer";
assert count(cfg_splat, "OmnibusSigProc") == 0 : "splat has no OmnibusSigProc";
assert chain(cfg_splat) == [
    "DepoSetBoundarySource->DepoSetDrifter",
    "DepoSetDrifter->DepoFluxSplat",
    "DepoFluxSplat->Reframer",
    "Reframer->FrameBoundarySink",
] : "splat chain";

// --- shared services across islands (anodes) --------------------------------
// Anode-independent services are named by content, so two anodes (two WCT
// islands of one Phlex job) with the same field response etc. name the same
// instance; per-anode state keeps per-anode names; RNG seeds differ per anode.
local cfg_v0   = sim_sigproc(detector="fdvd", anode_index="0", variant="v8");
local cfg_v1   = sim_sigproc(detector="fdvd", anode_index="1", variant="v8");
local cfg_v200 = sim_sigproc(detector="fdvd", anode_index="200", variant="v8");
local names(cfg, t) = [c.name for c in cfg if c.type == t];
local shared_types = ["FftwDFT", "FieldResponse", "ColdElecResponse", "PlaneImpactResponse", "WireSchemaFile"];
assert std.all([names(cfg_v0, t) == names(cfg_v1, t) for t in shared_types])
       : "anodes 0 and 1 (same volume) share DFT, FR, elec, PIRs, wires";
assert names(cfg_v0, "FieldResponse") == names(cfg_v200, "FieldResponse")
       && names(cfg_v0, "PlaneImpactResponse") != names(cfg_v200, "PlaneImpactResponse")
       : "bottom/top anodes share the FR but not the PIRs (different electronics)";
assert names(cfg_v0, "AnodePlane") != names(cfg_v1, "AnodePlane")
       && names(cfg_v0, "Random") != names(cfg_v1, "Random")
       && names(cfg_v0, "EmpiricalNoiseModel") != names(cfg_v1, "EmpiricalNoiseModel")
       : "anode, RNG and noise model stay per anode";
local seeds(cfg) = [c.data.seeds for c in cfg if c.type == "Random"][0];
assert seeds(cfg_v0) != seeds(cfg_v1) : "per-anode RNG seeds";

// --- detector-wide drift + drifted/hydra islands -----------------------------
local drift = import "dune/wct/job/drift.jsonnet";
local cfg_drift = drift(detector="fdvd", variant="v8");
assert chain(cfg_drift) == [
    "DepoSetBoundarySource->DepoSetDrifter",
    "DepoSetDrifter->DepoSetBoundarySink",
] : "drift chain";
assert std.length([c for c in cfg_drift if c.type == "Drifter"][0].data.xregions) == 2
       : "detector drift covers both FD-VD drift volumes";
local cfg_hy = sim_sigproc(detector="fdvd", anode_index="120", variant="v8", drifted="yes", hydra="yes");
assert std.sort(chain(cfg_hy)) == std.sort([
    "DepoSetBoundarySource->DepoSetFilter",
    "DepoSetFilter->DeposOrBust",
    "DeposOrBust->DepoTransform",
    "DeposOrBust->FrameSync",
    "DepoTransform->Reframer",
    "Reframer->AddNoise",
    "AddNoise->Digitizer",
    "Digitizer->OmnibusSigProc",
    "OmnibusSigProc->FrameSync",
    "FrameSync->FrameBoundarySink",
]) : "drifted + hydra island chain";
assert count(cfg_hy, "Drifter") == 0 : "a drifted island does not drift";
assert [c.data.frame_ident for c in cfg_hy if c.type == "DepoTransform"] == ["deposet"]
       : "frames name their event";

{ ok: true }
