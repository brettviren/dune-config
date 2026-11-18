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
// Detector tasks add one entry each:
//   pdhd  -- beads ddm-4pz.4   (+ "real" variant, ddm-4pz.13)
//   pdvd  -- beads ddm-4pz.5
//   fdhd  -- beads ddm-4pz.14, xero-80b.1.1 (from dunereco dune10kt-1x2x6/-hd)
//   fdvd  -- beads ddm-4pz.15  (from dunereco dune10kt-vd)

{
    pdhd: import "detectors/pdhd/detector.jsonnet",
    pdsp: import "detectors/pdsp/detector.jsonnet",
    pdvd: import "detectors/pdvd/detector.jsonnet",
    fdvd: import "detectors/fdvd/detector.jsonnet",
    fdhd: import "detectors/fdhd/detector.jsonnet",
}
