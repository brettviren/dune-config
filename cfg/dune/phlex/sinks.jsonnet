// cfg/dune/phlex/sinks.jsonnet
//
// phlex sink modules keyed by job-level output kind -- the phlex-layer mirror of
// the WCT output ends.  Each entry declares the product it consumes and a
// make(filename, input_from) -> phlex sink-module spec.  `input_from` is the
// instance name of the upstream (executor) module whose product to write
// (phlex routes by creator = module instance name).
//
// wct_config values name generic file-IO WCT graphs from wire-cell-phlex.

{
    "frame-file":: {
        product:: "frame",
        make(filename, input_from):: {
            cpp: "wcp_frame_sink_file",
            wct_config: "frame-file-sink.jsonnet",
            wct_plugins: ["WireCellPgraph", "WireCellSio"],
            input_layer: "event",
            input_from: input_from,
            wct_tla: { outname: filename },
        },
    },

    "deposet-file":: {
        product:: "deposet",
        make(filename, input_from):: {
            cpp: "wcp_deposet_sink_file",
            wct_config: "deposet-file-sink.jsonnet",
            wct_plugins: ["WireCellPgraph", "WireCellSio"],
            input_layer: "event",
            input_from: input_from,
            wct_tla: { outname: filename },
        },
    },
}
