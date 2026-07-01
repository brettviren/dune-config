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
assert sim.modules.sink.cpp == "wcp_frame_sink_file" : "sim sink";
assert frm.modules.sink.cpp == "wcp_frame_sink_file" : "frame sink";
assert daq.modules.sink.cpp == "wcp_frame_sink_file" : "daq sink";

// sim: deposet source -> sim-sigproc body (drift+sim+SP) via deposet_to_frame
assert sim.sources.source.cpp == "wcp_deposet_source_file" : "sim reads deposets";
assert sim.modules.wct.cpp == "wcp_deposet_to_frame" : "sim executor";
assert sim.modules.wct.wct_config == "dune/wct/job/sim-sigproc.jsonnet" : "sim body";

// frame-file: frame source -> sigproc body via frame_filter
assert frm.sources.source.cpp == "wcp_frame_source_file" : "frame reads frames";
assert frm.modules.wct.cpp == "wcp_frame_filter" : "frame executor";
assert frm.modules.wct.wct_config == "dune/wct/job/sigproc.jsonnet" : "frame body";

// daq-hdf: SAME SP processing + sink as frame-file; ONLY the source differs.
assert daq.modules == frm.modules : "daq-hdf shares the frame-file SP processing + sink";
assert daq.sources != frm.sources : "daq-hdf differs only in the input source";
assert daq.sources.source.cpp == "wcp_daq_hdf_source" : "daq-hdf gated source module";

// detector + variant ride through the swap unchanged
assert sim.modules.wct.wct_tla.detector == "pdhd" : "detname carried";
local realv = sp(detname="pdvd", sp_input="sim", variant="real");
assert realv.modules.wct.wct_tla.variant == "real" : "variant carried";
assert realv.modules.wct.wct_tla.detector == "pdvd" : "detname carried (pdvd)";

{ ok: true }
