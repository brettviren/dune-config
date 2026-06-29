// test/schema-variant-test.jsonnet
//
// Self-contained test of dune/wct/lib/{schema,variant}.jsonnet (beads ddm-4pz.3).
// Imports only those libs (no wirecell), so it runs with: jsonnet -J cfg.
// Uses raw numbers (no units) for a synthetic detector.

local schema  = import "dune/wct/lib/schema.jsonnet";
local variant = import "dune/wct/lib/variant.jsonnet";

local mk_anode(i, gain) = {
    ident:   i,
    name:    "a%d" % i,
    faces:   [{ anode: 0, response: 1, cathode: 2 }],
    elec:    { type: "ColdElecResponse", gain: gain, shaping: 2.2, postgain: 1.0 },
    field:   { filename: "fr.json.bz2" },
    // filter_response intentionally omitted -> structural default (null)
    noise:   { filename: "noise.json.bz2", wire_length_scale: 1.0 },
    adc:     { resolution: 14, gain: 1.0, baselines: [1, 1, 1], fullscale: [0.2, 1.6] },
    sigproc: { r_th_factor: 3.0 },
};

local base = schema.make({
    name:           "demo",
    daq:            { tick: 0.5, nticks: 6000 },
    lar:            { DL: 1.0, DT: 1.0, lifetime: 8.0, drift_speed: 1.6 },
    sim:            { fluctuate: true, tick0_time: -250, nsigma: 3, nimpacts: 10 },
    response_plane: 10,
    wires:          { filename: "wires.json.bz2" },
    anodes:         [mk_anode(0, 14.0), mk_anode(1, 14.0)],
    sp_filters:     [],
});

// --- structural defaults applied by make() ---------------------------------
assert base.anodes[0].filter_response == null
       : "anode structural default (filter_response: null) not applied";
assert base.sys_status == false
       : "detector structural default (sys_status: false) not applied";

// --- variant selection ------------------------------------------------------
assert variant.select({}) == "ideal"            : "default variant must be ideal";
assert variant.select({ variant: "real" }) == "real" : "variant must be read from params";

// --- detector-level deep merge (apply) -------------------------------------
local longer = variant.apply(base, { lar: { lifetime: 35.0 } });
assert longer.lar.lifetime == 35.0    : "apply() did not override lar.lifetime";
assert longer.lar.drift_speed == 1.6  : "apply() must deep-merge (preserve lar siblings)";

// --- per-anode patch (patch_anodes) ----------------------------------------
local real = variant.patch_anodes(base, { "1": { elec: { gain: 7.8 } } });
assert real.anodes[0].elec.gain == 14.0  : "anode 0 must be unchanged";
assert real.anodes[1].elec.gain == 7.8   : "anode 1 gain must be patched";
assert real.anodes[1].elec.shaping == 2.2: "patch must deep-merge (preserve elec siblings)";

// --- patched detector is still schema-valid --------------------------------
local _ = schema.validate(real);

{ ok: true }
