// cfg/dune/phlex/sp-job.jsonnet
//
// Signal-processing job with a SWAPPABLE input source (beads ddm-4pz.10).
//
// The single knob `sp_input` selects where the ADC frames fed to OmnibusSigProc
// come from -- simulation, a frame file, or raw DUNE-DAQ HDF5 -- by mapping to
// the (in_kind, wct_job) pair the general workflow() builder needs.  Swapping
// the input is therefore PURELY a job-config change, no new job file:
//
//   sp_input        in_kind        wct_job        status
//   --------        -------        -------        ------
//   "sim"           deposet-file   sim-sigproc    live  (drift+sim then SP)
//   "frame-file"    frame-file     sigproc        live  (SP on file frames)
//   "daq-hdf"       daq-hdf        sigproc        GATED (Phlex 0.3.0 DAQ source,
//                                                 ddm-3j8.1.6); config assembles
//                                                 but needs the unbuilt module.
//
// All three produce signal-processed frames at the output (out_kind=frame-file).

local workflow = import "workflow.jsonnet";

local plan = {
    "sim":        { in_kind: "deposet-file", wct_job: "sim-sigproc" },
    "frame-file": { in_kind: "frame-file",   wct_job: "sigproc" },
    "daq-hdf":    { in_kind: "daq-hdf",       wct_job: "sigproc" },
};

function(
    detname,
    sp_input      = "sim",
    in_file       = "input.npz",
    out_file      = "signals.npz",
    variant       = "ideal",
    anode_index   = 0,
    nevents       = 1,
    wct_log_sink  = "",
    wct_log_level = "",
)

assert std.objectHas(plan, sp_input)
       : "unknown sp_input %s (expected one of %s)" % [sp_input, std.objectFields(plan)];

local p = plan[sp_input];

workflow(
    detname=detname,
    wct_job=p.wct_job,
    in_kind=p.in_kind,
    out_kind="frame-file",
    in_file=in_file,
    out_file=out_file,
    variant=variant,
    anode_index=anode_index,
    nevents=nevents,
    wct_log_sink=wct_log_sink,
    wct_log_level=wct_log_level,
)
