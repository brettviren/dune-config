// cfg/dune/phlex/sources.jsonnet
//
// phlex source modules keyed by job-level input kind -- the phlex-layer mirror
// of the WCT input ends (dune/wct/lib/ends.jsonnet).  Each entry declares the
// product it provides and a make(filename) -> phlex source-module spec.
//
// The wct_config values name GENERIC file-IO WCT graphs provided by
// wire-cell-phlex (resolved on the runtime search path), NOT dune-specific
// configs -- the phlex and wct config domains stay separate.
//
// Note: a "sim" signal-processing job reads DEPOSETS, so at the phlex layer it
// uses the "deposet-file" source (its sim-ness lives in the WCT body it runs).
// The four job-level input kinds therefore map onto these source kinds in the
// SP-input swap (ddm-4pz.10):
//   sim -> deposet-file (+ wct_job sim-sigproc),  frame-file -> frame-file,
//   daq-hdf -> daq-hdf  (+ wct_job sigproc).

{
    "deposet-file":: {
        product:: "deposet",
        make(filename):: {
            cpp: "wcp_deposet_source_file",
            wct_config: "deposet-file-source.jsonnet",
            wct_plugins: ["WireCellPgraph", "WireCellSio"],
            output_layer: "event",
            wct_tla: { inname: filename },
        },
    },

    "frame-file":: {
        product:: "frame",
        make(filename):: {
            cpp: "wcp_frame_source_file",
            wct_config: "frame-file-source.jsonnet",
            wct_plugins: ["WireCellPgraph", "WireCellSio"],
            output_layer: "event",
            wct_tla: { inname: filename },
        },
    },

    // STUB, gated on Phlex 0.3.0 source/driver + the DUNE-DAQ decode source
    // (beads ddm-3j8.1.6).  A workflow using this ASSEMBLES, but running it needs
    // the not-yet-built phlex DAQ source module + its generic IO config.
    "daq-hdf":: {
        product:: "frame",
        gated:: true,
        make(filename):: {
            cpp: "wcp_daq_hdf_source",             // FUTURE module (ddm-3j8.1.6)
            wct_config: "daq-hdf-source.jsonnet",   // FUTURE generic IO config
            wct_plugins: ["WireCellPgraph", "WireCellSio"],
            output_layer: "event",
            wct_tla: { inname: filename },
        },
    },
}
