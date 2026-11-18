// cfg/dune/phlex/gdml.jsonnet
//
// Per detector: the GDML file a Phlex job reads its geometry from (by
// variant, "default" for any other), and how wire-cell-phlex's
// wcph_gdml_geometry turns it into a WCT wire schema and drift planes:
// the LArSoft channel map ("readout") and TPC sorter it ports, and the
// grouping of TPCs into WCT anodes and faces.  Pure data (Phlex side).
//
// Each entry reproduces the LArSoft geometry of that detector: the made
// wire schema equals the WCT wires file named in the detector's
// dune/wct/detectors/<det>/detector.jsonnet channel for channel, with
// endpoints within 0.01 mm (wire-cell-phlex test/gdml_wires_check):
//
//   pdhd  protodunehd_v{1,6,7,8}_refactored.gdml vs protodunehd-wires-larsoft-v1
//         (dunecore ProtoDUNEWireReadoutGeom = DuneApaWireReadoutGeom +
//         WireReadoutSorterAPA, GeoObjectSorterAPA)
//   pdvd  protodunevd_v4_refactored.gdml vs protodunevd-wires-larsoft-v3
//         (protodunevd_v5_ggd.gdml vs -v4) (CRPWireReadoutGeom,
//         GeoObjectSorterCRU60D with SortTPCPDVD)
//   fdvd  dunevd10kt_3view_30deg_v8_full10kt_ggd.gdml vs
//         fdvd-v8-fromgeo-pairtpc (CRPWireReadoutGeom, GeoObjectSorterCRU60D)
//   fdhd  dune10kt_v6_refactored.gdml vs dune10kt_v7_refactored (833100 wires),
//         dune10kt_v6_refactored_1x2x6.gdml vs dune10kt-1x2x6-wires-larsoft-v1,
//         dune10kt_v6_refactored_1x2x2.gdml vs its anodes 0-3 (dunecore
//         DuneApaWireReadoutGeom + WireReadoutSorterAPA, GeoObjectSorterAPA:
//         names containing "dune10kt", as PDHD's but without its optical
//         channel overrides).  The full GDML's 50 wall-side faces come out
//         insensitive.

{
    pdhd: {
        files: { default: "protodunehd_v8_refactored.gdml" },
        readout: "apa",
        sorter: "apa",
        grouping: "pair-tpc",
    },
    pdvd: {
        files: { default: "protodunevd_v4_refactored.gdml" },
        readout: "crp",
        sorter: "cru60d-pdvd",
        grouping: "pair-tpc",
    },
    fdvd: {
        files: {
            v6: "dunevd10kt_3view_30deg_v6_refactored.gdml",
            default: "dunevd10kt_3view_30deg_v8_full10kt_ggd.gdml",
        },
        readout: "crp",
        sorter: "cru60d",
        grouping: "pair-tpc",
    },
    fdhd: {
        files: {
            "1x2x6": "dune10kt_v6_refactored_1x2x6.gdml",
            "1x2x2": "dune10kt_v6_refactored_1x2x2.gdml",
            default: "dune10kt_v6_refactored.gdml",
        },
        readout: "apa",
        sorter: "apa",
        grouping: "pair-tpc",
    },
}
