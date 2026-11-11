// cfg/dune/phlex/sinks.jsonnet
//
// phlex sink modules keyed by job-level output kind -- the phlex-layer mirror of
// the WCT output ends.  Each entry declares the product it consumes and a
// make(filename, input_from) -> phlex sink-module spec in the wire-cell-phlex
// shape-executor form (cpp "wcph_<type>_sink").  `input_from` is the module
// label of the upstream executor whose product to write: a Phlex transform's
// output creator is its own module label, and its layer is its input's layer.
//
// wct_config values name generic file-IO WCT graphs from wire-cell-phlex.

local wcph_sink(product, wct_config) = {
    product:: product,
    make(filename, input_from):: {
        cpp: "wcph_" + product + "_sink",
        wct_config: wct_config,
        wct_plugins: ["WireCellPgraph", "WireCellSio"],
        inputs: [{ creator: input_from, layer: "event", suffix: product }],
        outputs: [],
        wct_tla: { outname: filename },
    },
};

{
    "frame-file":: wcph_sink("frame", "frame-file-sink.jsonnet"),
    "deposet-file":: wcph_sink("deposet", "deposet-file-sink.jsonnet"),
}
