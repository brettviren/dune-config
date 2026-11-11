// test/phlex-test.jsonnet
//
// phlex workflow builder (beads ddm-4pz.9).  Self-contained: workflow.jsonnet is
// pure data (no wirecell.jsonnet, only references WCT configs by filename), so
// this runs with:  jsonnet -J cfg.

local workflow = import "dune/phlex/workflow.jsonnet";

// --- SP fed by simulation: deposets -> sim-sigproc -> frames ---------------
local sim_sp = workflow(
    detname="pdhd", wct_job="sim-sigproc",
    in_kind="deposet-file", out_kind="frame-file",
    in_file="depos.npz", out_file="frames.npz",
);
assert sim_sp.driver.cpp == "generate_layers" : "driver";
assert sim_sp.stage == "sim-sigproc" : "stage defaults to the WCT job name";
assert workflow(detname="pdhd", wct_job="sigproc", stage="sp").stage == "sp" : "stage override";
assert sim_sp.sources.source.cpp == "wcph_deposet_source" : "deposet source module";
assert sim_sp.sources.source.wct_tla.inname == "depos.npz" : "input file";
assert sim_sp.modules.wct.cpp == "wcph_deposet_to_frame" : "deposet->frame executor";
assert sim_sp.modules.wct.wct_config == "dune/wct/job/sim-sigproc.jsonnet" : "references WCT body";
assert sim_sp.modules.wct.wct_tla.detector == "pdhd" : "detname TLA";
assert sim_sp.modules.wct.wct_tla.variant == "ideal" : "variant TLA default";
assert sim_sp.modules.wct.wct_tla.anode_index == "0" : "anode_index TLA is a string";
assert sim_sp.modules.sink.cpp == "wcph_frame_sink" : "frame sink module";
assert sim_sp.modules.sink.inputs == [{ creator: "wct", layer: "event", suffix: "frame" }]
       : "sink reads the executor's product";
assert sim_sp.modules.wct.inputs == [{ creator: "input", layer: "event", suffix: "deposet" }]
       : "executor reads the source's product";
assert sim_sp.modules.wct.outputs == [{ suffix: "frame" }] : "executor output suffix only";
assert sim_sp.sources.source.inputs == [] : "source has no inputs";
assert sim_sp.modules.sink.wct_tla.outname == "frames.npz" : "output file";

// --- SP fed by a frame file: frames -> sigproc -> frames -------------------
local frame_sp = workflow(detname="pdvd", wct_job="sigproc", in_kind="frame-file");
assert frame_sp.sources.source.cpp == "wcph_frame_source" : "frame source module";
assert frame_sp.modules.wct.cpp == "wcph_frame_filter" : "frame->frame executor";
assert frame_sp.modules.wct.wct_config == "dune/wct/job/sigproc.jsonnet" : "references sigproc body";
assert frame_sp.modules.wct.wct_tla.detector == "pdvd" : "detname";

// --- variant plumbed through to the WCT job --------------------------------
local realvar = workflow(detname="pdhd", wct_job="sim-sigproc", variant="real");
assert realvar.modules.wct.wct_tla.variant == "real" : "variant override reaches the WCT TLA";

// --- daq-hdf assembles (gated module referenced) ---------------------------
local daq_sp = workflow(detname="pdhd", wct_job="sigproc", in_kind="daq-hdf");
assert daq_sp.sources.source.cpp == "dune_daq_phlex_source" : "daq-hdf source (gated module)";
assert daq_sp.modules.wct.cpp == "wcph_frame_filter" : "still a frame->frame executor";

// --- anode_index, nevents, optional WCT logging ----------------------------
local withlog = workflow(
    detname="pdhd", wct_job="sigproc", in_kind="frame-file",
    anode_index=2, nevents=5, wct_log_sink="stderr", wct_log_level="info",
);
assert withlog.modules.wct.wct_tla.anode_index == "2" : "anode_index override";
assert withlog.driver.layers.event.total == 5 : "nevents";
assert withlog.modules.wct.wct_log_sink == "stderr" : "log sink attached";
assert withlog.modules.wct.wct_log_level == "info" : "log level attached";
// logging knobs omitted when not requested
assert !std.objectHas(frame_sp.modules.wct, "wct_log_sink") : "no log knob by default";

// --- registries expose the expected kinds ----------------------------------
local sources = import "dune/phlex/sources.jsonnet";
local sinks   = import "dune/phlex/sinks.jsonnet";
assert sinks["deposet-file"].make("x.npz", "wct").cpp == "wcph_deposet_sink"
       : "deposet sink module in registry";
assert sources["daq-hdf"].gated == true : "daq-hdf source is marked gated";

{ ok: true }
