// cfg/dune/wct/detectors.jsonnet
//
// The detector registry: canonical detname -> function(params) -> description.
//
// Selection contract (unchanged across variants): a caller does
//
//   local dets = import "dune/wct/detectors.jsonnet";
//   local det  = dets[params.detname](params);   // params.variant picks overlay
//
// Each function is a lazy import (parsed only when accessed), built on
// dune/wct/lib/schema.jsonnet and dune/wct/lib/variant.jsonnet.
//
// This registry starts empty; detector tasks add one entry each:
//   pdhd  -- beads ddm-4pz.4   (+ "real" variant, ddm-4pz.13)
//   pdvd  -- beads ddm-4pz.5
//   fd-hd -- beads ddm-4pz.14
//   fd-vd -- beads ddm-4pz.15

{
    pdhd: import "detectors/pdhd/detector.jsonnet",
    // pdvd: import "detectors/pdvd/detector.jsonnet",
}
