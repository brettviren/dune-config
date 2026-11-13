// cfg/dune/phlex/workflow.jsonnet
//
// Parameterized phlex workflow builder (beads ddm-4pz.9).
//
//   workflow(detname, wct_job, in_kind, out_kind, ...) -> phlex workflow object
//
// Assembles a complete single-anode phlex job: a generate_layers driver, one
// source module (per in_kind), one WCT executor module that runs a dune/wct/job
// config, and one sink module (per out_kind).  The executor cpp is chosen from
// the (source product -> sink product) flow.  The detector + variant + anode are
// passed to the WCT job as TLAs; the workflow only REFERENCES the WCT job-config
// by filename (the phlex and wct config domains stay separate).
//
// Swapping the SP input (sim / frame-file / raw-DAQ) is a change of in_kind
// (+ matching wct_job) -- the ddm-4pz.10 milestone, e.g.
//   sim     : workflow(d, "sim-sigproc", in_kind="deposet-file", ...)
//   frames  : workflow(d, "sigproc",     in_kind="frame-file",   ...)
//   raw DAQ : workflow(d, "sigproc",     in_kind="daq-hdf",      ...)   [gated]
//
// Geometry from GDML instead of a WCT wires file: give gdml=<file> (a path or
// a name on GDML_PATH).  The workflow then adds phlex-gdml's provider
// (pgd_provider: GDML -> gdml::DocumentPtr at the job layer) and
// wire-cell-phlex's wcph_gdml_geometry transforms (-> wire schema and drift
// faces, job layer), gives the executor those two products as extra inputs
// ("geometry" config; WCT is configured on its first call) and passes
// geometry="phlex" to the WCT job, which then uses FacadeWireSchema /
// FacadeDriftPlanes.  gdml_readout / gdml_grouping select the channel map and
// anode grouping (wire_cell_phlex/GdmlWires.hpp).

local sources = import "sources.jsonnet";
local sinks   = import "sinks.jsonnet";

// WCT executor module per data-flow (wire-cell-phlex shape executors; cpp is
// the plugin library name, libwcph_<cpp-suffix>.so).  Plugins are a superset
// sufficient for any of the dune/wct/job bodies (Gen for sim, SigProc for
// sigproc, Aux/Pgraph always).
local executors = {
    deposet_to_frame: {
        cpp: "wcph_deposet_to_frame",
        wct_plugins: ["WireCellPgraph", "WireCellGen", "WireCellSigProc", "WireCellAux"],
    },
    deposet_to_deposet: {
        cpp: "wcph_deposet_filter",   // registers node wcph_deposet_to_deposet
        wct_plugins: ["WireCellPgraph", "WireCellGen", "WireCellAux"],
    },
    frame_to_frame: {
        cpp: "wcph_frame_filter",   // registers node wcph_frame_to_frame
        wct_plugins: ["WireCellPgraph", "WireCellGen", "WireCellSigProc", "WireCellAux"],
    },
};

function(
    detname,
    wct_job,                       // dune/wct/job basename: sim|sigproc|sim-sigproc|splat
    in_kind       = "deposet-file",
    out_kind      = "frame-file",
    in_file       = "input.npz",
    out_file      = "output.npz",
    variant       = "ideal",
    anode_index   = 0,
    nevents       = 1,
    wct_log_sink  = "",
    wct_log_level = "",
    stage         = "",            // phlex job stage (required by Phlex >= 0.4); "" -> wct_job
    gdml          = "",            // GDML file: geometry from GDML (see above); "" -> wires file
    gdml_readout  = "crp",
    gdml_grouping = "pair-tpc",
    // Several anodes in one job: one executor island (module "wct<n>") and
    // one sink ("sink<n>", writing out_file with "-a<n>" before ".npz") per
    // anode, all reading the same source (and geometry).  [] -> anode_index.
    anode_indices = [],
    // Where depos are drifted (sim-sigproc only):
    //   "island": each anode's WCT island drifts the event's depos itself;
    //   "job":    one "drift" module drifts them once over the whole detector
    //             (dune/wct/job/drift.jsonnet) and every island takes the
    //             drifted depos and keeps its anode's (DepoSetFilter), as the
    //             art multi-sim drifts once ahead of its fanout.
    drift         = "island",
    // With drift "job": an island whose anode has no depos skips sim and
    // sigproc and gives an empty frame (WCT hydra: DeposOrBust + FrameSync).
    hydra         = false,
)

local src = sources[in_kind];
local snk = sinks[out_kind];
local exkey = src.product + "_to_" + snk.product;
assert std.objectHas(executors, exkey)
       : "no phlex executor for %s flow (in_kind=%s, out_kind=%s)" % [exkey, in_kind, out_kind];
local ex = executors[exkey];

local exec_inst = "wct";

assert drift == "island" || drift == "job" : 'drift must be "island" or "job", got "%s"' % drift;
local drift_job = drift == "job";
assert !drift_job || wct_job == "sim-sigproc" : 'drift "job" needs wct_job "sim-sigproc"';
assert !hydra || drift_job : 'hydra needs drift "job"';

local use_gdml = gdml != "";

// Job-layer geometry: provider + transforms, and the executor's extra inputs.
local geo_sources = if use_gdml then {
    gdml: { cpp: "pgd_provider", gdml: gdml, creator: "gdml", suffix: "gdml", layer: "job" },
} else {};
local geo_modules = if use_gdml then {
    geometry: {
        cpp: "wcph_gdml_geometry",
        input: { creator: "gdml", layer: "job", suffix: "gdml" },
        readout: gdml_readout,
        grouping: gdml_grouping,
    },
} else {};
local geo_exec = if use_gdml then {
    geometry: {
        key: "geometry",
        wire_schema: { creator: "geometry", layer: "job", suffix: "wire_schema" },
        drift_faces: { creator: "geometry", layer: "job", suffix: "drift_faces" },
    },
} else {};

// Conditionally attach WCT logging knobs to the executor module.
local with_log = {
    [if wct_log_sink  != "" then "wct_log_sink"]:  wct_log_sink,
    [if wct_log_level != "" then "wct_log_level"]: wct_log_level,
};

// The detector-wide drift module (drift "job") and what the islands read.
local drift_label = "drift";
local drift_modules = if drift_job then {
    [drift_label]: {
        cpp: executors.deposet_to_deposet.cpp,
        wct_config: "dune/wct/job/drift.jsonnet",
        wct_plugins: executors.deposet_to_deposet.wct_plugins,
        inputs: [src.output],
        outputs: [{ suffix: "deposet" }],
        wct_tla: {
            detector: detname,
            anode_index: "%d" % anode_index,
            variant: variant,
        } + (if use_gdml then { geometry: "phlex" } else {}),
    } + with_log + geo_exec,
} else {};
local island_input = if drift_job
    then { creator: drift_label, layer: src.output.layer, suffix: "deposet" }
    else src.output;

local executor(n) = {
    cpp: ex.cpp,
    wct_config: "dune/wct/job/" + wct_job + ".jsonnet",
    wct_plugins: ex.wct_plugins,
    inputs: [island_input],
    // a transform's output creator/layer are fixed by Phlex (its module
    // label and its input's layer); only the suffix is set
    outputs: [{ suffix: snk.product }],
    wct_tla: {
        detector:    detname,
        anode_index: "%d" % n,  // phlex TLAs are strings
        variant:     variant,
    } + (if use_gdml then { geometry: "phlex" } else {})
      + (if drift_job then { drifted: "yes", hydra: if hydra then "yes" else "no" } else {}),
} + with_log + geo_exec;

// Signal processing output carries "gauss" and "wiener" traces; write them
// as separate arrays (the frame sink's "*" would sum them per channel).
local sink_tags = if out_kind == "frame-file" && std.member(["sigproc", "sim-sigproc"], wct_job)
    then "gauss,wiener" else "";

local per_anode_file(n) =
    if std.endsWith(out_file, ".npz")
    then std.substr(out_file, 0, std.length(out_file) - 4) + "-a%d.npz" % n
    else out_file + "-a%d" % n;

{
    stage: if stage == "" then wct_job else stage,

    driver: {
        cpp: "generate_layers",
        layers: { event: { parent: "job", total: nevents, starting_number: 1 } },
    },

    sources: {
        source: src.make(in_file),
    } + geo_sources,

    modules: (if std.length(anode_indices) == 0 then {
        [exec_inst]: executor(anode_index),
        sink: snk.make(out_file, exec_inst, sink_tags),
    } else std.foldl(function(acc, n) acc + {
        ["wct%d" % n]: executor(n),
        ["sink%d" % n]: snk.make(per_anode_file(n), "wct%d" % n, sink_tags),
    }, anode_indices, {})) + geo_modules + drift_modules,
}
