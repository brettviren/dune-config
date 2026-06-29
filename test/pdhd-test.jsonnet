// test/pdhd-test.jsonnet
//
// Builds the PDHD detector through the registry (beads ddm-4pz.4) and checks the
// per-anode specials and the param-override branches.  Imports wirecell.jsonnet
// transitively, so run with:  jsonnet -J cfg -J <prefix>/share/wirecell.
//
// (Full parity vs the wire-cell-phlex / dunereco references is beads ddm-4pz.11;
// that port was verified byte-identical to the wire-cell-phlex original during
// this task.)

local dets = import "dune/wct/detectors.jsonnet";

local det = dets.pdhd({ detname: "pdhd" });

// --- shape ------------------------------------------------------------------
assert det.name == "pdhd" : "name";
assert std.length(det.anodes) == 4 : "PDHD has 4 APAs";
assert [a.name for a in det.anodes] == ["apa0", "apa1", "apa2", "apa3"] : "apa names";
assert std.length(det.sp_filters) == 16 : "PDHD has 16 SP filters (13 + 3 APA1-variant)";
assert det.sys_status == false : "sys_status structural default";

// --- APA0 specials (6-path MCMC field response) -----------------------------
local a0 = det.anodes[0];
assert a0.field.filename == "np04hd-garfield-6paths-mcmc-bestfit.json.bz2" : "APA0 field";
assert a0.filter_response != null : "APA0 has a filter_response";
assert a0.sigproc.plane2layer == [0, 2, 1] : "APA0 plane2layer";
assert a0.sigproc.wiener_filters ==
       ["Wiener_tight_U_APA1", "Wiener_tight_V_APA1", "Wiener_tight_W_APA1"]
       : "APA0 uses APA1-variant Wiener names";

// --- APA1 standard ----------------------------------------------------------
local a1 = det.anodes[1];
assert a1.field.filename == "dune-garfield-1d565.json.bz2" : "APA1 field";
assert a1.filter_response == null : "APA1 has no filter_response";
assert a1.sigproc.plane2layer == [0, 1, 2] : "APA1 plane2layer";
assert a1.sigproc.wiener_filters ==
       ["Wiener_tight_U", "Wiener_tight_V", "Wiener_tight_W"]
       : "APA1 uses standard Wiener names";

// --- default variant is the base -------------------------------------------
assert dets.pdhd({ detname: "pdhd", variant: "ideal" }) == det : "ideal == default";

// --- param overrides --------------------------------------------------------
// lar override flows through (raw value here; real callers use wc units).
local longlife = dets.pdhd({ detname: "pdhd", lar: { lifetime: 35000 } });
assert longlife.lar.lifetime == 35000 : "lar.lifetime override";
assert det.lar.lifetime != 35000 : "base unaffected by override";

// elec_gain selects the noise-spectra file.
assert det.anodes[0].noise.filename == "protodunehd-noise-spectra-14mVfC-v1.json.bz2"
       : "default 14 mV/fC noise file";
local lowgain = dets.pdhd({ detname: "pdhd", elec_gain: 7.8 });
assert lowgain.anodes[0].noise.filename == "protodunehd-noise-spectra-7d8mVfC-v1.json.bz2"
       : "7.8 mV/fC noise file";

{ ok: true }
