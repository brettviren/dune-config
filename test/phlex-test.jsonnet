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


// --- drift once for all islands, hydra, SP sink tags -------------------------
local dj = workflow(
    detname="fdvd", wct_job="sim-sigproc", variant="v8",
    in_file="depos.npz", out_file="sig.npz",
    anode_indices=[3, 200], drift="job", hydra=true,
);
assert dj.modules.drift.cpp == "wcph_deposet_filter" : "drift module is a deposet->deposet executor";
assert dj.modules.drift.wct_config == "dune/wct/job/drift.jsonnet" : "drift module runs drift.jsonnet";
assert dj.modules.drift.inputs == [{ creator: "input", layer: "event", suffix: "deposet" }]
       : "drift reads the source";
assert dj.modules.wct3.inputs == [{ creator: "drift", layer: "event", suffix: "deposet" }]
       : "islands read the drifted depos";
assert dj.modules.wct200.wct_tla.drifted == "yes" && dj.modules.wct200.wct_tla.hydra == "yes"
       : "islands told depos are drifted, hydra on";
assert dj.modules.sink3.wct_tla.tags == "gauss,wiener" : "SP output written per tag";
assert !std.objectHas(sim_sp.modules, "drift") && !std.objectHas(sim_sp.modules.wct.wct_tla, "drifted")
       : "default: islands drift themselves";

// --- all anodes in one WCT graph ----------------------------------------------
local cj = workflow(
    detname="fdvd", wct_job="sim-sigproc", variant="v8",
    in_file="depos.npz", out_file="sig.npz",
    anode_indices=[3, 200], drift="job", hydra=true, combine=true,
);
assert std.objectFields(cj.modules) == ["drift", "sink", "wct"] : "drift, one executor, one sink";
assert cj.modules.wct.wct_config == "dune/wct/job/multi-sim-sigproc.jsonnet" : "combined WCT job";
assert cj.modules.wct.wct_tla.anode_indices == "3,200" && cj.modules.wct.wct_tla.hydra == "yes"
       : "anodes and hydra passed as TLA strings";
assert cj.modules.wct.inputs == [{ creator: "drift", layer: "event", suffix: "deposet" }]
       : "combined graph reads the drifted depos";
assert cj.modules.sink.wct_tla == { outname: "sig.npz", tags: "gauss,wiener" } : "one output file";
assert !std.objectHas(cj.modules.wct, "wct_app") && !std.objectHas(cj.modules.wct.wct_tla, "app_type")
       : "Pgrapher by default";
local tj = workflow(
    detname="fdvd", wct_job="sim-sigproc", variant="v8", anode_indices=[3, 200],
    drift="job", combine=true, wct_app="TbbFlow",
);
assert tj.modules.wct.wct_app == "TbbFlow" && tj.modules.wct.wct_tla.app_type == "TbbFlow"
       && std.member(tj.modules.wct.wct_plugins, "WireCellTbb")
       && tj.modules.drift.wct_app == "TbbFlow" && tj.modules.drift.wct_tla.app_type == "TbbFlow"
       : "TbbFlow engine for every executor";

{ ok: true }
