// cfg/dune/wct/detectors/fdvd/detector.jsonnet
//
// DUNE Far Detector Vertical Drift (FD-VD, LArSoft "dunevd10kt", geometry v6
// 2x8x40) detector description for dune-config.
//
// Returns a plain-data detector description (see dune/wct/lib/schema.jsonnet).
// No WCT component configs are embedded here except sp_filters.  WCT component
// construction happens in dune/wct/job/*.jsonnet functions that consume this.
//
// Transcribed from dunereco DUNEWireCell/dune10kt-vd/ (branch pdvd-to-fdvd,
// 2d4d01ba): params-10kt.jsonnet, sim.jsonnet, sp.jsonnet, sp-filters.jsonnet
// and the FHiCL knobs of wcls-fdvd-sim-sigproc.fcl (nticks, DL, DT, lifetime,
// efield, temperature, G4RefTime, elecGain, response_plane, files_*).
//
// Anodes: 320 two-face anodes, ident 0-319.  One anode is one CRU (a LArSoft
// TPC set: two CRMs = two LArSoft TPCs whose U/V strips are jumpered), so its
// two faces have the same drift geometry.  Anodes 0-159 are in the bottom
// drift volume (anode plane at X ~ -6.52 m, drift toward -X), 160-319 in the
// top drift volume (X ~ +6.52 m, drift toward +X); the cathode is at X ~ 0.
//
// Bottom and top drift volumes have DIFFERENT front-end electronics:
//   bottom: cold electronics (BDE), ColdElecResponse, gain selectable
//           (4.7/7.8/14/25 mV/fC; noise spectra exist only for 7.8 and 14),
//           ADC baselines ~1003/1003/508 mV, full scale 0.2-1.6 V;
//   top:    top drift electronics (TDE), JsonElecResponse from a measured
//           response file, ADC baselines 1 V, full scale 0-2 V.
// Each anode carries its own elec/noise/adc/sigproc, so this is per-anode
// data in the schema (as for PDVD).  Both volumes use the same CRP strip
// geometry as PDVD and therefore the PDVD field response and noise spectra.
//
// Arguments:
//   params: override object.  params.detname = "fdvd".
//           params.variant selects a variant (default "ideal"):
//             ideal   -- bottom (BDE) gain 14 mV/fC (the FHiCL default)
//             bde7d8  -- bottom (BDE) gain 7.8 mV/fC (and its noise spectra)
//           Optional fields (merged): lar, daq, sim; elec_gain (bottom gain
//           in mV/fC, a number, used by the "ideal" variant).
//           Example: {detname:"fdvd", lar:{lifetime: 3*wc.ms}}
//
// WIRES FILE WARNING: two different files are named
// dunevd10kt_3view_30deg_v6_refactored.json.bz2.  wire-cell-data (0.2.0,
// md5 8fbfb503...) holds a 2023 version whose wires are offset by 5-16 mm in
// y/z from the current geometry; dunereco dune10kt-vd/ (8f6efbb9, 2026-05-03,
// md5 939166d2...) holds the one made from the current v6 GDML.  Which one a
// job loads depends on WIRECELL_PATH order: put dunereco's dune10kt-vd/ (or
// its install) before wire-cell-data.

local wc      = import "wirecell.jsonnet";
local schema  = import "../../lib/schema.jsonnet";
local variant = import "../../lib/variant.jsonnet";

function(params={detname: "fdvd"})

// ---------------------------------------------------------------------------
// Geometry constants (params-10kt.jsonnet det.volumes)
// ---------------------------------------------------------------------------
local nanodes = 320;
local is_top(ident) = ident >= nanodes / 2;

// Collection-plane X of each drift volume and the anode-cathode distance.
// The current v6 wires file has the bottom W plane at -651.99 cm and the top
// at +652.15 cm; dunereco keeps -651.90 cm for the bottom (0.9 mm off W).
local bot_anode_x = -651.90 * wc.cm;
local top_anode_x =  652.15 * wc.cm;
local anode_cathode = 650.06 * wc.cm;

// Response plane: distance from the collection strips where the field
// response paths start.  MUST match the field response file.
local response_plane = 18.1 * wc.cm;
local field_file = "protodunevd_FR_imbalance3p_260501.json.bz2";
// Drift speed the field response file was computed with (its "speed").
local field_speed = 1.53 * wc.mm / wc.us;

// ---------------------------------------------------------------------------
// Defaults (override via params.{lar,daq,sim})
// ---------------------------------------------------------------------------
local lar_defaults = {
    // dunesim simulationservices_dune.fcl dunefd_largeantparameters
    // (inherited by dunefdvd_largeantparameters): 4.0e-9 / 8.8e-9 cm^2/ns.
    DL:          4.0 * wc.cm2 / wc.s,
    DT:          8.8 * wc.cm2 / wc.s,
    // wcls-fdvd-sim-sigproc.fcl lifetime (= dunefdvd_detproperties 10.4e3 us).
    lifetime:    10.4 * wc.ms,
    // protodunevd funcs.drift_velocity(efield=0.5 kV/cm, temperature=87 K),
    // the dunefdvd_detproperties values.
    drift_speed: 1.6056288906533873 * wc.mm / wc.us,
};

local daq_defaults = {
    tick:   0.5 * wc.us,
    // dunefdvd_detproperties.NumberTimeSamples
    nticks: 8500,
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

// SP time offset.  The field response starts at response_plane and assumes
// field_speed; correct for the simulated drift speed (dunereco 64b94591;
// the PDVD 4 us is tuned to PDVD data).  Uses the resolved lar so a
// params.lar.drift_speed override stays consistent.  -5.57 us by default.
local ctoffset = response_plane / lar.drift_speed - response_plane / field_speed;

// Bottom (BDE) noise spectra, selected by front-end gain as in
// params-10kt.jsonnet.  Files exist only for 7.8 and 14 mV/fC.
local bottom_noise(gain) =
    local g = gain / (wc.mV / wc.fC);
    if std.abs(g - 7.8) < 0.05 then "pdvd-bottom-noise-spectra-7d8mVfC-v1.json.bz2"
    else if std.abs(g - 14.0) < 0.05 then "pdvd-bottom-noise-spectra-14mVfC-v1.json.bz2"
    else error ("fdvd bottom noise: no spectra file for elec gain " + g
                + " mV/fC (cold electronics settings are 4.7/7.8/14/25 mV/fC;"
                + " spectra exist only for 7.8 and 14)");

// ---------------------------------------------------------------------------
// Per-anode entry builder
// ---------------------------------------------------------------------------
local make_anode(n, bde_gain) =
    local top = is_top(n);
    // +1: drift toward +X (top volume), -1: toward -X (bottom volume)
    local sign = if top then 1 else -1;
    local anode_x = if top then top_anode_x else bot_anode_x;
    local face = {
        anode:    anode_x,
        response: anode_x - sign * response_plane,
        cathode:  anode_x - sign * anode_cathode,
    };
    {
        ident: n,
        name: "anode%d" % n,

        // A CRU: both faces have the same drift geometry.
        faces: [face, face],

        elec: if top then {
            // Top drift electronics (TDE)
            type:     "JsonElecResponse",
            filename: "dunevd-coldbox-elecresp-top-psnorm_400.json.bz2",
            postgain: 1.36,  // 11 mV/fC (1.94 -> 14 mV/fC)
        } else {
            // Bottom drift, cold electronics (BDE)
            type:     "ColdElecResponse",
            gain:     bde_gain,
            shaping:  2.2 * wc.us,
            postgain: 1.0,
        },

        // Same CRP strips as PDVD: its field response, for both volumes.
        field: {
            filename: field_file,
            response_plane: response_plane,
        },

        filter_response: null,

        noise: {
            filename: if top
                then "pdvd-top-noise-spectra-v3.json.bz2"
                else bottom_noise(bde_gain),
            wire_length_scale: 1.0 * wc.cm,
        },

        adc: {
            resolution: 14,
            gain:       1.0,
            baselines: if top
                then [1.0 * wc.volt, 1.0 * wc.volt, 1.0 * wc.volt]
                else [1003.4 * wc.mV, 1003.4 * wc.mV, 507.7 * wc.mV],
            fullscale: if top
                then [0.0 * wc.volt, 2.0 * wc.volt]
                else [0.2 * wc.volt, 1.6 * wc.volt],
        },

        // OmnibusSigProc tuning from dune10kt-vd/sp.jsonnet (non-DNNROI path,
        // use_dnnroi false: sparse, no multi-plane protection).  Same for
        // both volumes; the per-volume difference reaches SP through the
        // anode's elec (elecresponse) and adc (ADC_mV).
        //
        // NOTE: troi_col_th_factor is the production 5.0.  For PDVD with its
        // "norminal" field response, bare OSP at 5.0 left the collection
        // plane empty and dune-config PDVD uses 2.5 (ddm-tv6).  FD-VD uses a
        // different field response (imbalance3p); not yet checked here.
        sigproc: {
            ctoffset:    ctoffset,
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
// Detector description for a given bottom (BDE) front-end gain.
// ---------------------------------------------------------------------------
local make_detector(bde_gain) = schema.make({
    name: "fdvd",

    daq: daq,
    lar: lar,
    sim: sim,

    // See the WIRES FILE WARNING above.
    wires: {
        filename: "dunevd10kt_3view_30deg_v6_refactored.json.bz2",
    },

    anodes: [make_anode(n, bde_gain) for n in std.range(0, nanodes - 1)],

    sp_filters: import "sp-filters.jsonnet",

    // Response systematics (off: sys_status defaults false)
    sys_resp: {
        start:      0.0 * wc.us,
        magnitude:  1.0,
        time_smear: 1.0 * wc.us,
    },
    // As PDVD: no RC response in the simulation.
    rc_resp: {
        width:     1.1 * wc.ms,
        rc_layers: 0,
    },

    // DepoFluxSplat.  No empirically derived smearing for FD-VD yet ("wcpy
    // gen morse-*"); zeros as for PDVD.  The window is derived per anode in
    // job/parts.jsonnet.
    splat: {
        sparse:         true,
        reference_time: 0.0,
        smear_long: [0.0, 0.0, 0.0],
        smear_tran: [0.0, 0.0, 0.0],
    },

    // Extent of the wire planes in the current v6 wires file (informational).
    bounds: {
        tail: wc.point(-6.52, -6.73,  0.0,  wc.m),
        head: wc.point( 6.53,  6.73, 59.77, wc.m),
    },
});

// ---------------------------------------------------------------------------
// Variants.  Built lazily: only the selected one is evaluated.
// ---------------------------------------------------------------------------
local variants = {
    ideal:  make_detector(std.get(params, "elec_gain", 14.0) * wc.mV / wc.fC),
    bde7d8: make_detector(7.8 * wc.mV / wc.fC),
};

local vname = variant.select(params);
assert std.objectHas(variants, vname)
       : "fdvd: unknown variant '" + vname + "' (have: "
         + std.join(", ", std.objectFields(variants)) + ")";

variants[vname]
