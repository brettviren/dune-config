// test/fdhd-test.jsonnet
//
// Builds the FD-HD detector through the registry (xero-80b.1.1) and checks
// its geometry variants and the values transcribed from dunereco
// DUNEWireCell/dune10kt-1x2x6 and dune10kt-hd.  Run with:
//   jsonnet -J cfg -J <prefix>/share/wirecell

local wc     = import "wirecell.jsonnet";
local schema = import "dune/wct/lib/schema.jsonnet";
local dets   = import "dune/wct/detectors.jsonnet";

local det = dets.fdhd({ detname: "fdhd" });
local w6  = dets.fdhd({ detname: "fdhd", variant: "1x2x6" });
local w2  = dets.fdhd({ detname: "fdhd", variant: "1x2x2" });

local near(a, b, tol=1e-6) = std.abs(a - b) <= tol * std.max(1, std.abs(b));
local within(a, b, d) = std.abs(a - b) <= d;

// --- shape ------------------------------------------------------------------
assert det.name == "fdhd" : "name";
assert std.length(det.anodes) == 150 : "full FD-HD has 150 APAs";
assert std.length(w6.anodes) == 12 : "1x2x6 has 12 APAs";
assert std.length(w2.anodes) == 4 : "1x2x2 has 4 APAs";
assert [a.ident for a in det.anodes] == std.range(0, 149) : "dense idents";
assert det.anodes[17].name == "apa17" : "anode names";
assert schema.validate(w6) == w6 : "1x2x6 validates, every anode";
assert schema.validate(det) == det : "full detector validates, every anode";
assert dets.fdhd({ detname: "fdhd", variant: "ideal" }) == det : "ideal == default";
assert det.wires.filename == "dune10kt_v7_refactored.json.bz2" : "full wires";
assert w6.wires.filename == "dune10kt-1x2x6-wires-larsoft-v1.json.bz2" : "1x2x6 wires";
assert w2.wires.filename == w6.wires.filename : "1x2x2 reads the 1x2x6 wires (anodes 0-3)";
assert det.daq.nticks == 6000 : "dunereco nticks";

// --- drift geometry ---------------------------------------------------------
// Collection planes from the GDML / wires files: +-30.02 mm about the APA
// centre; APA rows at X = -7270.5, 0, +7270.5 mm (anode n in row n%3).
local wplane(f) = f.anode + (if f.response > f.anode then -1 else 1) * 9.52 * wc.mm;
assert std.all([
    local a = det.anodes[n];
    local cx = (n % 3 - 1) * 7270.525 * wc.mm;
    within(wplane(a.faces[0]), cx + 30.02 * wc.mm, 0.01 * wc.mm)
    && within(wplane(a.faces[1]), cx - 30.02 * wc.mm, 0.01 * wc.mm)
    for n in std.range(0, 149)
]) : "full: face 0 at higher X, collection planes match the wires file";
assert std.all([a.faces == w6.anodes[0].faces for a in w6.anodes]) : "1x2x6: one APA row at X=0";
assert w2.anodes == w6.anodes[0:4] : "1x2x2 = first four 1x2x6 anodes";
assert std.all([a.faces[0].anode < a.faces[0].response && a.faces[0].response < a.faces[0].cathode
                && a.faces[1].anode > a.faces[1].response && a.faces[1].response > a.faces[1].cathode
                for a in w6.anodes])
       : "face 0 drifts toward -X from +X, face 1 the reverse";
// GDML cathode faces at +-3633.76 mm (cpa_plane 3633.68 mm).
assert within(w6.anodes[0].faces[0].cathode, 3633.68 * wc.mm, 0.01 * wc.mm) : "cathode";
assert within(det.drift_planes.anode_offset, 9.52 * wc.mm, 0.01 * wc.mm) : "anode offset as PDHD";

// --- electronics, responses, SP (dunereco dune10kt-1x2x6) -------------------
local a0 = det.anodes[0];
assert a0.elec.type == "ColdElecResponse" : "cold electronics";
assert near(a0.elec.gain, 14 * wc.mV / wc.fC) : "14 mV/fC";
assert near(a0.elec.shaping, 2.2 * wc.us) : "2.2 us shaping";
assert a0.elec.postgain == 1.1365 : "pulser-calibrated postgain";
assert a0.field == { filename: "dune-garfield-1d60563.json.bz2", response_plane: 10 * wc.cm } : "field";
assert a0.noise.filename == "protodune-noise-spectra-v1.json.bz2" : "dunereco noise spectra";
assert a0.adc.resolution == 14 : "14-bit ADC";
assert a0.sigproc.ctoffset == 1.0 * wc.us : "ctoffset";
assert near(det.lar.drift_speed, 1.60563 * wc.mm / wc.us) : "drift speed = FR file speed";
assert std.all([a.elec == a0.elec && a.field == a0.field && a.sigproc == a0.sigproc
                && a.noise == a0.noise && a.adc == a0.adc for a in det.anodes])
       : "all APAs alike";
assert std.length(det.sp_filters) == 13 : "13 SP filters";
assert det.sp_filters == dets.fdvd({ detname: "fdvd" }).sp_filters : "same filters as FD-VD (dunereco)";

// a gain override reaches the electronics
assert near(dets.fdhd({ detname: "fdhd", elec_gain: 7.8 }).anodes[3].elec.gain, 7.8 * wc.mV / wc.fC)
       : "elec_gain override";

{ ok: true }
