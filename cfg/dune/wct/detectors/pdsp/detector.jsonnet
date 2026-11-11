// cfg/dune/wct/detectors/pdsp/detector.jsonnet
//
// ProtoDUNE-SP (PDSP) detector description for dune-config.
//
// Returns a plain-data detector description (see dune/wct/lib/schema.jsonnet).
// No WCT component configs are embedded here except sp_filters (whose instance
// names are hard-coded in OmnibusSigProc C++).  WCT component construction
// happens in dune/wct/job/*.jsonnet functions that consume this object.
//
// Geometry source: protodune-wires-larsoft-v4 (LArSoft).
// Transcribed from pgrapher/experiment/pdsp/{params,simparams,sp,sp-filters}.jsonnet.
// The lar values (DL/DT/lifetime/drift_speed) match those pinned by the WCT
// reference test test/test/test-pdsp-simsn-nfsp.jsonnet, so a phlex PDSP job is
// directly comparable to that reference (xerosere ddm-3bu.9).
//
// PDSP is the 6-APA sibling of PDHD.  Unlike PDHD it uses ONE generic 1D field
// response for every APA (no APA0 MCMC best-fit), no SP filter_response
// correction, standard plane ordering, and the standard Wiener filter names.
//
// Face geometry: always sim-mode (both faces active per APA).
//
// Arguments:
//   params: override object.  params.detname = "pdsp".
//           params.variant selects a variant overlay (default "ideal").
//           Optional fields (merged): lar, daq, sim, elec_gain.

local wc      = import "wirecell.jsonnet";
local schema  = import "../../lib/schema.jsonnet";
local variant = import "../../lib/variant.jsonnet";

function(params={detname: "pdsp"})

// ---------------------------------------------------------------------------
// Geometry constants (protodune-wires-larsoft-v4; from pdsp/simparams.jsonnet)
// ---------------------------------------------------------------------------
local apa_cpa   = 3.63075 * wc.m;    // APA-CPA centerline separation (LArSoft)
local cpa_thick = 3.175   * wc.mm;   // 1/8", from Bo Yu (BNL), confirmed w/ LArSoft
local apa_w2w   = 85.725  * wc.mm;
local plane_gap = 4.76    * wc.mm;
local apa_g2g   = 114.3   * wc.mm;

// Anode cut-off: at the first induction wires (innermost plane), sim-mode.
local apa_plane = 0.5 * apa_g2g - plane_gap;

// Response plane: distance from collection wires where Garfield starts.
// MUST match the field response file used.
local response_plane = 10 * wc.cm;
local res_plane      = 0.5 * apa_w2w + response_plane;

// Cathode cut-off
local cpa_plane = apa_cpa - 0.5 * cpa_thick;

// ---------------------------------------------------------------------------
// Default electronics gain.  Override via params.elec_gain.
// ---------------------------------------------------------------------------
local elec_gain = std.get(params, "elec_gain", 14.0) * wc.mV / wc.fC;

// ---------------------------------------------------------------------------
// Assemble per-anode entries
// ---------------------------------------------------------------------------
local make_anode(n) =
    local sign       = 2 * (n % 2) - 1;   // APA0,2,4 -> -1; APA1,3,5 -> +1
    local centerline = sign * apa_cpa;
    {
        ident: n,
        name: "apa%d" % n,

        // Both faces active (sim-mode geometry).
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

        // Electronics response.  All PDSP APAs: ColdElecResponse, 14 mV/fC,
        // 2.2 us shaping, postgain 1.1365 (pulser calibration; pdsp/params).
        elec: {
            type:     "ColdElecResponse",
            gain:     elec_gain,
            shaping:  2.2 * wc.us,
            postgain: 1.1365,
        },

        // Field response file: one generic 1D response for every APA.
        field: {
            filename: "dune-garfield-1d565.json.bz2",
            // Distance from the collection plane where this file's paths start.
            response_plane: response_plane,
        },

        // PDSP has no SP deconvolution-correction filter_response.
        filter_response: null,

        // Noise spectra (protodune).
        noise: {
            filename: "protodune-noise-spectra-v1.json.bz2",
            wire_length_scale: 1.0 * wc.cm,
        },

        // ADC / digitizer settings (pdsp/params).  12-bit; induction baseline
        // 1003.4 mV, collection 507.7 mV; fullscale 0.2..1.6 V.
        adc: {
            resolution: 12,
            gain:       1.0,
            baselines:  [1003.4 * wc.mV, 1003.4 * wc.mV, 507.7 * wc.mV],
            fullscale:  [0.2 * wc.volt, 1.6 * wc.volt],
        },

        // OmnibusSigProc tuning, transcribed from pgrapher/experiment/pdsp/sp.jsonnet
        // ("Optimized May 2019").  Uniform across all 6 APAs (no APA0 special case).
        sigproc: {
            ctoffset:    1.0 * wc.us,
            ftoffset:    0.0,
            postgain:    1.0,
            fft_flag:    0,
            troi_col_th_factor: 5.0,   // toolkit pdsp: "// default 5"
            troi_ind_th_factor: 3.0,
            lroi_rebin:         6,
            lroi_th_factor:     3.5,
            lroi_th_factor1:    0.7,
            lroi_jump_one_bin:  1,
            r_th_factor: 3.0,
            r_fake_signal_low_th:             375,
            r_fake_signal_high_th:            750,
            r_fake_signal_low_th_ind_factor:  1.0,
            r_fake_signal_high_th_ind_factor: 1.0,
            r_th_peak:   3.0,
            r_sep_peak:  6.0,
            r_low_peak_sep_threshold_pre: 1200,
            use_roi_debug_mode:         false,
            use_multi_plane_protection: false,
            isWrapped:   false,
            sparse:      true,
            // Standard plane ordering (no APA0 swap) and standard Wiener names.
            plane2layer:    [0, 1, 2],
            wiener_filters: ["Wiener_tight_U", "Wiener_tight_V", "Wiener_tight_W"],
        },
    };

// ---------------------------------------------------------------------------
// Defaults (override via params.{lar,daq,sim}).  lar matches the WCT reference
// test (test-pdsp-simsn-nfsp.jsonnet) so phlex PDSP is comparable to it.
// ---------------------------------------------------------------------------
local lar_defaults = {
    DL:          4.0  * wc.cm2 / wc.s,
    DT:          8.8  * wc.cm2 / wc.s,
    lifetime:    10.4 * wc.ms,
    drift_speed: 1.565 * wc.mm / wc.us,
};

local daq_defaults = {
    tick:   0.5  * wc.us,
    nticks: 6000,
};

local sim_defaults = {
    fluctuate:  true,
    fixed:      true,
    continuous: false,
    tick0_time: -250 * wc.us,
    nsigma:     3,
    nimpacts:   10,
};

local lar = lar_defaults + std.get(params, "lar", {});
local sim = sim_defaults + std.get(params, "sim", {});
local daq = daq_defaults + std.get(params, "daq", {});

// ---------------------------------------------------------------------------
// Base (ideal) detector description, built + validated via the schema.
// ---------------------------------------------------------------------------
local base = schema.make({
    name: "pdsp",

    daq: daq,
    lar: lar,
    sim: sim,

    wires: {
        filename: "protodune-wires-larsoft-v4.json.bz2",
    },

    // 6 APAs: apa0 .. apa5
    anodes: [make_anode(n) for n in std.range(0, 5)],

    // SP filter components (detector-tuned; names hard-coded in C++)
    sp_filters: import "sp-filters.jsonnet",

    // Optional response systematics (off by default; sys_status defaults false)
    sys_resp: {
        start:      -10 * wc.us,
        magnitude:  1.0,
        time_smear: 1.0 * wc.us,
    },
    rc_resp: {
        width:     1.1 * wc.ms,
        rc_layers: 1,
    },

    // DepoFluxSplat parameters.  PDHD reuses these PDSP values (same
    // field-response family); values determined empirically ("wcpy gen morse-*").
    // The splat window (tick, start, duration) is derived per anode from its
    // field.response_plane in job/parts.jsonnet.
    splat: {
        sparse:          true,
        reference_time:  0.0,
        smear_long: [2.691862363980221, 2.6750200122535057, 2.7137567141154055],
        smear_tran: [0.7377218875719689, 0.7157764520393882, 0.13980698710556544],
    },

    bounds: {
        tail: wc.point(-4.0, 0.0, 0.0, wc.m),
        head: wc.point(+4.0, 6.1, 7.0, wc.m),
    },
});

// ---------------------------------------------------------------------------
// Variant selection.  PDSP currently exposes only the ideal base description.
// ---------------------------------------------------------------------------
local variants = {
    ideal: base,
};

local vname = variant.select(params);
assert std.objectHas(variants, vname)
       : "pdsp: unknown variant '" + vname + "' (have: "
         + std.join(", ", std.objectFields(variants)) + ")";

variants[vname]
