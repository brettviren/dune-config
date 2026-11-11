// cfg/dune/phlex/sources.jsonnet
//
// phlex source modules keyed by job-level input kind -- the phlex-layer mirror
// of the WCT input ends (dune/wct/lib/ends.jsonnet).  Each entry declares the
// product it provides and a make(filename) -> phlex source-module spec in the
// wire-cell-phlex shape-executor form (cpp "wcph_<type>_source", "inputs" /
// "outputs" arrays of {creator, layer, suffix}).
//
// The wct_config values name GENERIC file-IO WCT graphs provided by
// wire-cell-phlex (resolved on the runtime search path), NOT dune-specific
// configs -- the phlex and wct config domains stay separate.
//
// Every source output has creator "input" (a Phlex provider's creator), layer
// "event" and the product name as suffix; `output` gives that selector so the
// workflow can wire the downstream executor's "inputs" to it.
//
// Note: a "sim" signal-processing job reads DEPOSETS, so at the phlex layer it
// uses the "deposet-file" source (its sim-ness lives in the WCT body it runs).
// The four job-level input kinds therefore map onto these source kinds in the
// SP-input swap (ddm-4pz.10):
//   sim -> deposet-file (+ wct_job sim-sigproc),  frame-file -> frame-file,
//   daq-hdf -> daq-hdf  (+ wct_job sigproc).

local wcph_source(product, wct_config) = {
    product:: product,
    output:: { creator: "input", layer: "event", suffix: product },
    make(filename):: {
        cpp: "wcph_" + product + "_source",
        wct_config: wct_config,
        wct_plugins: ["WireCellPgraph", "WireCellSio"],
        inputs: [],
        outputs: [$.output],
        wct_tla: { inname: filename },
    },
};

{
    "deposet-file":: wcph_source("deposet", "deposet-file-source.jsonnet"),

    "frame-file":: wcph_source("frame", "frame-file-source.jsonnet"),

    // STUB.  The working raw-DAQ chain is in scripts/cfg/daq-to-frame-file
    // .jsonnet: the dune_daq_phlex_driver + dune_daq_phlex_source (needs a
    // channel map) + wire_cell_phlex_arrow_from_arrow, whose frame then has
    // creator "from_arrow".  Wiring that here needs the workflow to take a
    // source-supplied driver and adapter module; until then a workflow using
    // this ASSEMBLES but does not run.
    "daq-hdf":: {
        product:: "frame",
        gated:: true,
        output:: { creator: "from_arrow", layer: "event", suffix: "frame" },
        make(filename):: {
            cpp: "dune_daq_phlex_source",
            input_file: filename,
            product: "frame",
            output_creator: "input",
            output_layer: "event",
        },
    },
}
