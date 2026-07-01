// test/ends-test.jsonnet
//
// I/O ends + bodies registries and the SP-input swap (beads ddm-4pz.8).
// Run with:  jsonnet -J cfg -J <prefix>/share/wirecell.

local g     = import "dune/wct/lib/graph.jsonnet";
local ends  = import "dune/wct/lib/ends.jsonnet";
local parts = import "dune/wct/job/parts.jsonnet";

local P = parts("pdhd", "0", "", "ideal");

// Assemble a signal-processing job with a chosen input KIND -- this is the
// ddm-4pz.10 swap expressed as a one-liner over the registries.
local sp_job(in_kind, src_name) =
    local input  = ends.inputs[in_kind](P, src_name);
    local body   = ends.bodies.sigproc(P);
    local output = ends.outputs["frame-file"](P, "wcphlex_frame_sink");
    g.application(
        g.pipeline(input.pnodes + body.pnodes + output.pnodes),
        name="wcphlex_pgrapher",
    );

local count(cfg, t) = std.length([c for c in cfg if c.type == t]);
local has(cfg, t)   = count(cfg, t) > 0;

// --- every frame-producing input kind yields a valid SP job ----------------
local from_sim   = sp_job("sim",        "wcphlex_deposet_source");
local from_frame = sp_job("frame-file", "wcphlex_frame_source");
local from_daq   = sp_job("daq-hdf",    "wcphlex_frame_source");

assert ends.frame_inputs == ["sim", "frame-file", "daq-hdf"] : "frame-producing input kinds";
assert count(from_sim, "OmnibusSigProc") == 1 : "sim->SP has sigproc";
assert count(from_frame, "OmnibusSigProc") == 1 : "frame->SP has sigproc";

// sim input brings the full sim chain; frame/daq inputs do not.
assert has(from_sim, "DepoSetBoundarySource") && has(from_sim, "Digitizer")
       : "sim input end drifts+digitizes";
assert has(from_frame, "FrameBoundarySource") && !has(from_frame, "Digitizer")
       : "frame input end is a bare frame boundary";

// --- the swap reproduces the dedicated job builders EXACTLY -----------------
// in_kind="sim"  == the sim-sigproc job; in_kind="frame-file" == the sigproc job.
local sim_sigproc_job = (import "dune/wct/job/sim-sigproc.jsonnet")(detector="pdhd", anode_index="0");
local sigproc_job     = (import "dune/wct/job/sigproc.jsonnet")(detector="pdhd", anode_index="0");
assert from_sim   == sim_sigproc_job : "sim-input SP job == sim-sigproc job";
assert from_frame == sigproc_job     : "frame-input SP job == sigproc job";

// daq-hdf is a WCT-level stub: same as frame-file (decode lives at phlex layer).
assert from_daq == from_frame : "daq-hdf stub == frame-file at the WCT level";

// --- output ends ------------------------------------------------------------
assert ends.outputs["frame-file"](P).pnodes[0].uses[0].type == "FrameBoundarySink"
       : "frame output sink";
assert ends.outputs["deposet-file"](P).pnodes[0].uses[0].type == "DepoSetBoundarySink"
       : "deposet output sink";

{ ok: true }
