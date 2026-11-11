// test/fdvd-test.jsonnet
//
// Builds the FD-VD detector through the registry (beads ddm-4pz.15) and checks
// its shape and the bottom (BDE) / top (TDE) electronics split.  Run with:
//   jsonnet -J cfg -J <prefix>/share/wirecell
//
// Values were cross-checked component by component against dunereco
// DUNEWireCell/dune10kt-vd (pdvd-to-fdvd 2d4d01ba) for anodes 0 and 200.

local wc   = import "wirecell.jsonnet";
local dets = import "dune/wct/detectors.jsonnet";

local det = dets.fdvd({ detname: "fdvd" });

// --- shape ------------------------------------------------------------------
assert det.name == "fdvd" : "name";
assert std.length(det.anodes) == 320 : "FD-VD has 320 anodes (CRUs)";
assert [a.ident for a in det.anodes] == std.range(0, 319) : "dense idents";
assert det.anodes[17].name == "anode17" : "anode names";
assert std.all([std.length(a.faces) == 2 && a.faces[0] == a.faces[1] for a in det.anodes])
       : "every anode has two faces with the same drift geometry";
assert std.length(det.sp_filters) == 13 : "13 SP filters";
assert det.daq.nticks == 8500 : "FD-VD readout is 8500 ticks";

// --- bottom drift (anodes 0-159): cold electronics --------------------------
local bot = det.anodes[0];
assert std.all([det.anodes[i].elec.type == "ColdElecResponse" for i in std.range(0, 159)])
       : "bottom volume uses ColdElecResponse";
assert std.abs(bot.elec.gain - 14 * wc.mV / wc.fC) < 1e-6 * bot.elec.gain : "default BDE gain 14 mV/fC";
assert bot.noise.filename == "pdvd-bottom-noise-spectra-14mVfC-v1.json.bz2" : "bottom noise file";
assert bot.faces[0].anode < bot.faces[0].response && bot.faces[0].response < bot.faces[0].cathode
       : "bottom drifts toward -X: anode < response < cathode";

// --- top drift (anodes 160-319): TDE ----------------------------------------
local top = det.anodes[160];
assert std.all([det.anodes[i].elec.type == "JsonElecResponse" for i in std.range(160, 319)])
       : "top volume uses JsonElecResponse";
assert top.elec.filename == "dunevd-coldbox-elecresp-top-psnorm_400.json.bz2" : "top elec file";
assert top.noise.filename == "pdvd-top-noise-spectra-v3.json.bz2" : "top noise file";
assert top.faces[0].anode > top.faces[0].response && top.faces[0].response > top.faces[0].cathode
       : "top drifts toward +X: anode > response > cathode";

assert bot.adc.fullscale != top.adc.fullscale : "bottom/top fullscale differ";
assert bot.adc.baselines != top.adc.baselines : "bottom/top baselines differ";

// --- field response and SP -------------------------------------------------
assert bot.field == top.field : "same field response in both volumes";
assert bot.field.response_plane == 18.1 * wc.cm : "response plane matches the FR file";
// ctoffset = response_plane/v_sim - response_plane/v_FR = -5.57 us at 1.6056 mm/us
assert std.abs(bot.sigproc.ctoffset / wc.us + 5.5722) < 1e-3 : "ctoffset from drift speeds";
assert bot.sigproc == top.sigproc : "same SP tuning in both volumes";

// a drift speed override moves ctoffset with it
local slow = dets.fdvd({ detname: "fdvd", lar: { drift_speed: 1.53 * wc.mm / wc.us } });
assert std.abs(slow.anodes[0].sigproc.ctoffset) < 1e-9 : "ctoffset 0 when v_sim == v_FR";

// --- variants ---------------------------------------------------------------
assert dets.fdvd({ detname: "fdvd", variant: "ideal" }) == det : "ideal == default";
local g78 = dets.fdvd({ detname: "fdvd", variant: "bde7d8" });
assert g78.anodes[0].noise.filename == "pdvd-bottom-noise-spectra-7d8mVfC-v1.json.bz2"
       : "bde7d8 bottom noise file";
assert g78.anodes[200] == det.anodes[200] : "bde7d8 leaves the top volume unchanged";

{ ok: true }
