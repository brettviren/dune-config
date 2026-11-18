// cfg/dune/wct/detectors/fdhd/detector.jsonnet
//
// DUNE Far Detector Horizontal Drift (FD-HD, LArSoft "dune10kt") detector
// description for dune-config.
//
// Returns a plain-data detector description (see dune/wct/lib/schema.jsonnet).
// No WCT component configs are embedded here except sp_filters.  WCT component
// construction happens in dune/wct/job/*.jsonnet functions that consume this.
//
// Transcribed from dunereco DUNEWireCell/ (branch pdvd-to-fdvd, 2d4d01ba; the
// FD-HD directories there equal DUNE/dunereco develop):
//   dune10kt-1x2x6/  params, simparams, sim, sp, sp-filters and
//                    wcls-sim-drift-simchannel-nf-sp.jsonnet (non-DNN-ROI
//                    path), the most recently maintained FD-HD config;
//   dune10kt-hd/     the full 150-APA geometry (apa_cpa, anode X layout);
//   wirecell_dune.fcl dunefd_horizdrift_1x2x6_sim_nfsp and the dunecore and
//                    dunesim FHiCL it reads: elecGain 14 mV/fC and Nbit 14
//                    (signalservices_dune.fcl *_standard), DL/DT
//                    (dunefd_largeantparameters), lifetime
//                    (dunefd_detproperties), driftSpeed 1.60563 mm/us,
//                    G4RefTime 0 (dunefd_detectorclocks).
//
// Anodes are APAs: two faces each, wrapped U/V induction wires shared by
// both faces (as PDHD).  Face 0 is the face at higher X.  Geometry variants:
//
//   ideal  the full detector, LArSoft dune10kt_v6 (dune10kt_v6_refactored.gdml):
//          150 APAs in three rows along X (anode n is in row n%3: X centre
//          -7.27, 0, +7.27 m), wires dune10kt_v7_refactored.json.bz2 (which,
//          despite its name, is made from the v6 GDML: wire-cell-phlex's GDML
//          port reproduces it wire for wire).
//   1x2x6  the 12-APA workspace (dune10kt_v6_refactored_1x2x6.gdml), one
//          APA row at X = 0, wires dune10kt-1x2x6-wires-larsoft-v1.json.bz2.
//          The configuration DUNE production simulates (dunesw
//          standard_detsim_dune10kt_1x2x6.fcl).
//   1x2x2  the 4-APA workspace (dune10kt_v6_refactored_1x2x2.gdml).  As in
//          dunereco dune10kt-1x2x2 it reads the 1x2x6 wires file, whose
//          anodes 0-3 equal the 1x2x2 GDML wire for wire.
//
// Physics (electronics, field and noise response, SP tuning) is the same in
// every variant.
//
// Outer APAs of the full detector: one face of each APA in rows 0 and 2
// looks at the cryostat wall (16 cm of LAr).  dunereco dune10kt-hd gives
// that face a full 3.6 m drift volume reaching beyond the cryostat, and the
// faces below ("file" geometry) do the same so that this description matches
// dunereco.  With geometry "phlex" the GDML drift planes mark those faces
// insensitive (null).
//
// Arguments:
//   params: override object.  params.detname = "fdhd".
//           params.variant selects a variant (default "ideal", see above).
//           Optional fields (merged): lar, daq, sim; elec_gain (front-end
//           gain in mV/fC, a number).
//           Example: {detname:"fdhd", variant:"1x2x6", lar:{lifetime: 3*wc.ms}}

local wc      = import "wirecell.jsonnet";
local schema  = import "../../lib/schema.jsonnet";
local variant = import "../../lib/variant.jsonnet";

function(params={detname: "fdhd"})

// ---------------------------------------------------------------------------
// APA geometry (dunereco dune10kt-hd params.jsonnet)
// ---------------------------------------------------------------------------
// Between APA and CPA centre lines.  dunereco dune10kt-1x2x6 still has
// 3.63075 m (an older GDML); the v6 GDML, the v7 wires file and dune10kt-hd
// have 3.635265 m (cathode face 3633.68 mm from the APA centre, GDML 3633.76).
local apa_cpa   = 3.635265 * wc.m;
local cpa_thick = 3.175 * wc.mm;     // 1/8"
// Collection to collection across the APA (GDML W planes at +-30.02 mm).
local apa_w2w   = 60.031 * wc.mm;
local plane_gap = 4.76 * wc.mm;
local apa_g2g   = apa_w2w + 6 * plane_gap;

// Anode cut-off: at the first induction wires.
local apa_plane = 0.5 * apa_g2g - plane_gap;

// Response plane: distance from the collection wires where the field
// response paths start.  MUST match the field response file.
local response_plane = 10 * wc.cm;
local res_plane      = 0.5 * apa_w2w + response_plane;

local cpa_plane = apa_cpa - 0.5 * cpa_thick;

// dunereco dune10kt-1x2x6 / dune10kt-hd files.fields.  Its drift speed
// ("speed" in the file) is 1.60563 mm/us, the simulated one, so SP needs no
// speed correction of ctoffset (compare fdvd).
local field_file = "dune-garfield-1d60563.json.bz2";

// Noise spectra: dunereco files.noise.  These are ProtoDUNE-SP spectra; WCT's
// own dune10kt-1x2x6 notes call them "bogus" for the FD.  An FD-HD APA is a
// PDHD APA with the same cold electronics, so
// protodunehd-noise-spectra-14mVfC-v1.json.bz2 is the better physical choice,
// but this description follows dunereco so that it can be validated against
// the art/LArSoft simulation.  Replace both together when DUNE does.
local noise_file = "protodune-noise-spectra-v1.json.bz2";

local geometries = {
    full: {
        wires: "dune10kt_v7_refactored.json.bz2",
        nanodes: 150,
        centerline(n): (n % 3 - 1) * 2 * apa_cpa,
        bounds: {
            tail: wc.point(-7240.51, -6001.20, 0.00,     wc.mm),
            head: wc.point( 7230.99,  6001.20, 58080.00, wc.mm),
        },
    },
    "1x2x6": {
        wires: "dune10kt-1x2x6-wires-larsoft-v1.json.bz2",
        nanodes: 12,
        centerline(n): 0,
        bounds: {
            tail: wc.point(-363.376, -600.019, -0.87625, wc.cm),
            head: wc.point( 363.376,  600.019, 1393.46,  wc.cm),
        },
    },
    "1x2x2": self["1x2x6"] {
        nanodes: 4,
    },
};

// ---------------------------------------------------------------------------
// Defaults (override via params.{lar,daq,sim})
// ---------------------------------------------------------------------------
local lar_defaults = {
    // dunesim dunefd_largeantparameters: 4.0e-9 / 8.8e-9 cm^2/ns.
    DL:          4.0 * wc.cm2 / wc.s,
    DT:          8.8 * wc.cm2 / wc.s,
    // dunecore dunefd_detproperties.Electronlifetime 10.4e3 us.
    lifetime:    10.4 * wc.ms,
    // dunefd_horizdrift_1x2x6_sim_nfsp driftSpeed.
    drift_speed: 1.60563 * wc.mm / wc.us,
};

local daq_defaults = {
    tick:   0.5 * wc.us,
    // dunereco dune10kt-1x2x6 daq.nticks.  (LArSoft's dunefd_detproperties
    // NumberTimeSamples is 4492; the WCT simulation and SP use 6000.)
    nticks: 6000,
};

local sim_defaults = {
    fluctuate:  true,
    fixed:      true,
    continuous: false,
    // dunefd_detectorclocks.G4RefTime = 0
    tick0_time: 0 * wc.us,
    nsigma:     3,
    nimpacts:   10,
};

local lar = lar_defaults + std.get(params, "lar", {});
local sim = sim_defaults + std.get(params, "sim", {});
local daq = daq_defaults + std.get(params, "daq", {});

// ASICGainInMVPerFC_standard
local elec_gain = std.get(params, "elec_gain", 14.0) * wc.mV / wc.fC;

// ---------------------------------------------------------------------------
// Per-anode entry builder
// ---------------------------------------------------------------------------
local make_anode(n, geo) =
    local centerline = geo.centerline(n);
    {
        ident: n,
        name: "apa%d" % n,

        faces: [
            {
                anode:    centerline + apa_plane,
                response: centerline + res_plane,
                cathode:  centerline + cpa_plane,
            },
            {
                anode:    centerline - apa_plane,
                response: centerline - res_plane,
                cathode:  centerline - cpa_plane,
            },
        ],

        elec: {
            type:     "ColdElecResponse",
            gain:     elec_gain,
            shaping:  2.2 * wc.us,
            // dunereco params elec.postgain: pulser calibration,
            // 41.649 ADC*tick/1ke.  Used by both sim and SP (one response).
            postgain: 1.1365,
        },

        field: {
            filename: field_file,
            response_plane: response_plane,
        },

        filter_response: null,

        noise: {
            filename: noise_file,
            wire_length_scale: 1.0 * wc.cm,
        },

        adc: {
            resolution: 14,   // Nbit_standard
            gain:       1.0,
            baselines:  [1003.4 * wc.mV, 1003.4 * wc.mV, 507.7 * wc.mV],
            fullscale:  [0.2 * wc.volt, 1.6 * wc.volt],
        },

        // OmnibusSigProc tuning from dune10kt-1x2x6/sp.jsonnet with the
        // non-DNN-ROI override of wcls-sim-drift-simchannel-nf-sp.jsonnet.
        // Keys dunereco leaves to the C++ defaults are written out:
        // isWrapped false, plane2layer [0,1,2], default Wiener names.
        //
        // sparse: dunereco runs OSP dense (sparse false) and its frame saver
        // writes sparse recob::Wire.  Here true, as for the other dune-config
        // detectors: the same samples, without the zeros (a dense 150-APA
        // event would be ~18 GB of SP output).
        sigproc: {
            ctoffset:    1.0 * wc.us,
            ftoffset:    0.0,
            postgain:    1.0,
            fft_flag:    0,
            troi_col_th_factor: 5.0,
            troi_ind_th_factor: 3.0,
            lroi_rebin:         6,
            lroi_th_factor:     3.5,
            lroi_th_factor1:    0.7,
            lroi_jump_one_bin:  1,
            r_th_factor:  3.0,
            r_fake_signal_low_th:             375,
            r_fake_signal_high_th:            750,
            r_fake_signal_low_th_ind_factor:  1.0,
            r_fake_signal_high_th_ind_factor: 1.0,
            r_th_peak:    3.0,
            r_sep_peak:   6.0,
            r_low_peak_sep_threshold_pre: 1200,
            use_roi_debug_mode:         false,
            use_multi_plane_protection: false,
            isWrapped:    false,
            sparse:       true,
            plane2layer:    [0, 1, 2],
            wiener_filters: ["Wiener_tight_U", "Wiener_tight_V", "Wiener_tight_W"],
        },
    };

// ---------------------------------------------------------------------------
// Detector description for one geometry.
// ---------------------------------------------------------------------------
local make_detector(geo) = schema.make({
    name: "fdhd",

    daq: daq,
    lar: lar,
    sim: sim,

    wires: {
        filename: geo.wires,
    },

    // Drift planes from geometry (GDML via Phlex): the same anode cut as the
    // faces above (first induction plane, 9.52 mm from the collection plane),
    // as PDHD.
    drift_planes: {
        anode_offset: apa_plane - 0.5 * apa_w2w,
    },

    anodes: [make_anode(n, geo) for n in std.range(0, geo.nanodes - 1)],

    // dunereco dune10kt-1x2x6/sp-filters.jsonnet, identical to FD-VD's.
    sp_filters: import "sp-filters.jsonnet",

    // dunereco dune10kt-1x2x6 simparams (sys_status false: off).
    sys_resp: {
        start:      -10 * wc.us,
        magnitude:  1.0,
        time_smear: 1.0 * wc.us,
    },
    rc_resp: {
        width:     1.1 * wc.ms,
        rc_layers: 0,
    },

    // DepoFluxSplat.  No values derived for FD-HD ("wcpy gen morse-*"); the
    // APA and field response are those of PDHD, which reuses PDSP's.  The
    // window is derived per anode in job/parts.jsonnet.
    splat: {
        sparse:          true,
        reference_time:  0.0,
        smear_long: [2.691862363980221, 2.6750200122535057, 2.7137567141154055],
        smear_tran: [0.7377218875719689, 0.7157764520393882, 0.13980698710556544],
    },

    // Extent of the wire planes (informational; dunereco det.bounds).
    bounds: geo.bounds,
});

// ---------------------------------------------------------------------------
// Variants.  Built lazily: only the selected one is evaluated.
// ---------------------------------------------------------------------------
local variants = {
    ideal:   make_detector(geometries.full),
    "1x2x6": make_detector(geometries["1x2x6"]),
    "1x2x2": make_detector(geometries["1x2x2"]),
};

local vname = variant.select(params);
assert std.objectHas(variants, vname)
       : "fdhd: unknown variant '" + vname + "' (have: "
         + std.join(", ", std.objectFields(variants)) + ")";

variants[vname]
