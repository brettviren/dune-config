// test/pdvd-test.jsonnet
//
// Builds the PDVD detector through the registry (beads ddm-4pz.5) and checks the
// bottom/top-drift split that exercises the schema's polymorphic elec and
// per-anode variation.  Run with:  jsonnet -J cfg -J <prefix>/share/wirecell.
//
// (The port was verified byte-identical to the wire-cell-phlex original during
// this task; full parity-vs-references harness is beads ddm-4pz.11.)

local dets = import "dune/wct/detectors.jsonnet";

local det = dets.pdvd({ detname: "pdvd" });

// --- shape ------------------------------------------------------------------
assert det.name == "pdvd" : "name";
assert std.length(det.anodes) == 8 : "PDVD has 8 anodes";
assert [a.name for a in det.anodes] == [
    "anode0", "anode1", "anode2", "anode3", "anode4", "anode5", "anode6", "anode7",
] : "anode names";
assert std.length(det.sp_filters) == 13 : "PDVD has 13 SP filters (no APA1-variant set)";
assert std.all([a.filter_response == null for a in det.anodes])
       : "PDVD has no frequency-domain filter_response on any anode";

// --- bottom drift (anode 0): ColdElecResponse -------------------------------
local bot = det.anodes[0];
assert bot.elec.type == "ColdElecResponse" : "bottom elec type";
assert std.objectHas(bot.elec, "gain") && std.objectHas(bot.elec, "shaping")
       : "ColdElecResponse carries gain+shaping";
assert !std.objectHas(bot.elec, "filename") : "ColdElecResponse has no filename";
assert bot.noise.filename == "pdvd-bottom-noise-spectra-v1.json.bz2" : "bottom noise file";

// --- top drift (anode 4): JsonElecResponse ----------------------------------
local top = det.anodes[4];
assert top.elec.type == "JsonElecResponse" : "top elec type";
assert top.elec.filename == "dunevd-coldbox-elecresp-top-psnorm_400.json.bz2" : "top elec file";
assert !std.objectHas(top.elec, "gain") : "JsonElecResponse has no gain field";
assert top.noise.filename == "pdvd-top-noise-spectra-v2.json.bz2" : "top noise file";

// bottom and top differ in digitizer ranges (compare without needing units)
assert bot.adc.fullscale != top.adc.fullscale : "bottom/top fullscale differ";
assert bot.adc.baselines != top.adc.baselines : "bottom/top baselines differ";

// --- SP tuning specific to PDVD --------------------------------------------
assert bot.sigproc.use_multi_plane_protection == true : "PDVD enables multi-plane protection";
assert bot.sigproc.troi_col_th_factor == 5.0 : "PDVD troi_col_th_factor";
assert bot.sigproc.plane2layer == [0, 1, 2] : "PDVD standard plane ordering";

// --- registry + default variant --------------------------------------------
assert std.objectHas(dets, "pdvd") && std.objectHas(dets, "pdhd")
       : "registry has both PD detectors";
assert dets.pdvd({ detname: "pdvd", variant: "ideal" }) == det : "ideal == default";

{ ok: true }
