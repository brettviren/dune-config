// test/sp-swap-test.jsonnet
//
// The SP-input swap (beads ddm-4pz.10): one knob `sp_input` selects sim /
// frame-file / raw-DAQ, changing ONLY the input source -- the SP processing +
// output stay fixed.  Self-contained: run with  jsonnet -J cfg.

local sp = import "dune/phlex/sp-job.jsonnet";

local sim = sp(detname="pdhd", sp_input="sim",        in_file="depos.npz",  out_file="sig.npz");
local frm = sp(detname="pdhd", sp_input="frame-file", in_file="digits.npz", out_file="sig.npz");
local daq = sp(detname="pdhd", sp_input="daq-hdf",    in_file="digits.npz", out_file="sig.npz");

// all three produce signal-processed frames at the same sink
assert sim.modules.sink.cpp == "wcph_frame_sink" : "sim sink";
assert frm.modules.sink.cpp == "wcph_frame_sink" : "frame sink";
assert daq.modules.sink.cpp == "wcph_frame_sink" : "daq sink";

// sim: deposet source -> sim-sigproc body (drift+sim+SP) via deposet_to_frame
assert sim.sources.source.cpp == "wcph_deposet_source" : "sim reads deposets";
assert sim.modules.wct.cpp == "wcph_deposet_to_frame" : "sim executor";
assert sim.modules.wct.wct_config == "dune/wct/job/sim-sigproc.jsonnet" : "sim body";

// frame-file: frame source -> sigproc body via frame_filter
assert frm.sources.source.cpp == "wcph_frame_source" : "frame reads frames";
assert frm.modules.wct.cpp == "wcph_frame_filter" : "frame executor";
assert frm.modules.wct.wct_config == "dune/wct/job/sigproc.jsonnet" : "frame body";

// daq-hdf: SAME SP processing + sink as frame-file; ONLY the source differs.
local but_inputs(m) = { [k]: m[k] for k in std.objectFields(m) if k != "inputs" };
assert daq.modules.sink == frm.modules.sink : "daq-hdf shares the frame-file sink";
assert but_inputs(daq.modules.wct) == but_inputs(frm.modules.wct)
       : "daq-hdf shares the frame-file SP processing (only its input creator differs)";
assert daq.modules.wct.inputs[0].creator == "from_arrow" : "daq frames come from the Arrow adapter";
assert daq.sources != frm.sources : "daq-hdf differs only in the input source";
assert daq.sources.source.cpp == "dune_daq_phlex_source" : "daq-hdf gated source module";

// detector + variant ride through the swap unchanged
assert sim.modules.wct.wct_tla.detector == "pdhd" : "detname carried";
local realv = sp(detname="pdvd", sp_input="sim", variant="real");
assert realv.modules.wct.wct_tla.variant == "real" : "variant carried";
assert realv.modules.wct.wct_tla.detector == "pdvd" : "detname carried (pdvd)";

{ ok: true }
