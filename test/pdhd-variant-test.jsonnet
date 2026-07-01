// test/pdhd-variant-test.jsonnet
//
// PDHD ideal-vs-real variant overlay (beads ddm-4pz.13).
// Run with:  jsonnet -J cfg -J <prefix>/share/wirecell.

local dets   = import "dune/wct/detectors.jsonnet";
local schema = import "dune/wct/lib/schema.jsonnet";

local ideal = dets.pdhd({ detname: "pdhd", variant: "ideal" });
local real  = dets.pdhd({ detname: "pdhd", variant: "real" });

// default selects the ideal (base) variant
assert dets.pdhd({ detname: "pdhd" }) == ideal : "default variant must be ideal";

// the as-built APA0 swaps its field response; ideal keeps the MCMC best-fit
assert ideal.anodes[0].field.filename == "np04hd-garfield-6paths-mcmc-bestfit.json.bz2"
       : "ideal APA0 field";
assert real.anodes[0].field.filename == "np04hd-garfield-6paths.json.bz2"
       : "real APA0 field (as-built measured 6-path response)";

// the other three APAs are untouched by the overlay
assert real.anodes[1] == ideal.anodes[1] : "APA1 unchanged";
assert real.anodes[2] == ideal.anodes[2] : "APA2 unchanged";
assert real.anodes[3] == ideal.anodes[3] : "APA3 unchanged";

// APA0 differs ONLY in field: patching the field back recovers ideal APA0
assert real.anodes[0] { field: ideal.anodes[0].field } == ideal.anodes[0]
       : "real APA0 differs from ideal only in field";

// nothing outside `anodes` changed: restoring ideal anodes recovers ideal
assert real { anodes: ideal.anodes } == ideal
       : "real and ideal differ only within anodes";

// the patched detector is still schema-valid
local _ = schema.validate(real);

{ ok: true }
