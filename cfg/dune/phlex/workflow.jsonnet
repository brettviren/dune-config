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

local sources = import "sources.jsonnet";
local sinks   = import "sinks.jsonnet";

// WCT executor module per data-flow.  Plugins are a superset sufficient for any
// of the dune/wct/job bodies (Gen for sim, SigProc for sigproc, Aux/Pgraph always).
local executors = {
    deposet_to_frame: {
        cpp: "wcp_deposet_to_frame",
        wct_plugins: ["WireCellPgraph", "WireCellGen", "WireCellSigProc", "WireCellAux"],
    },
    frame_to_frame: {
        cpp: "wcp_frame_filter",
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
)

local src = sources[in_kind];
local snk = sinks[out_kind];
local exkey = src.product + "_to_" + snk.product;
assert std.objectHas(executors, exkey)
       : "no phlex executor for %s flow (in_kind=%s, out_kind=%s)" % [exkey, in_kind, out_kind];
local ex = executors[exkey];

local exec_inst = "wct";

// Conditionally attach WCT logging knobs to the executor module.
local with_log = {
    [if wct_log_sink  != "" then "wct_log_sink"]:  wct_log_sink,
    [if wct_log_level != "" then "wct_log_level"]: wct_log_level,
};

{
    driver: {
        cpp: "generate_layers",
        layers: { event: { parent: "job", total: nevents, starting_number: 1 } },
    },

    sources: {
        source: src.make(in_file),
    },

    modules: {
        [exec_inst]: {
            cpp: ex.cpp,
            wct_config: "dune/wct/job/" + wct_job + ".jsonnet",
            wct_plugins: ex.wct_plugins,
            input_layer: "event",
            wct_tla: {
                detector:    detname,
                anode_index: "%d" % anode_index,  // phlex TLAs are strings
                variant:     variant,
            },
        } + with_log,

        sink: snk.make(out_file, exec_inst),
    },
}
