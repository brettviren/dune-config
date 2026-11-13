// cfg/dune/wct/detectors/pdhd/detector.jsonnet
//
// ProtoDUNE-HD (PDHD) detector description for dune-config.
//
// Returns a plain-data detector description (see dune/wct/lib/schema.jsonnet).
// No WCT component configs are embedded here except sp_filters (whose instance
// names are hard-coded in OmnibusSigProc C++).  WCT component construction
// happens in dune/wct/job/*.jsonnet functions that consume this object.
//
// Geometry source: protodunehd_v6 GDML.
// Transcribed from dunereco/DUNEWireCell/pdhd/{params,simparams}.jsonnet
// (via wire-cell-phlex/cfg/dune/wct/dets/pdhd/detector.jsonnet).
//
// Face geometry: always sim-mode (both faces active per APA).  Data-mode jobs
// that only need one face per APA can filter the faces array.
//
// Arguments:
//   params: override object.  params.detname = "pdhd".
//           params.variant selects a variant overlay (default "ideal").
//           Optional fields (merged): lar, daq, sim, elec_gain.
//           Example: {detname:"pdhd", lar:{lifetime: 35*wc.ms}}

local wc      = import "wirecell.jsonnet";
local schema  = import "../../lib/schema.jsonnet";
local variant = import "../../lib/variant.jsonnet";

function(params={detname: "pdhd"})

// ---------------------------------------------------------------------------
// Geometry constants (from protodunehd_v6 GDML)
// ---------------------------------------------------------------------------
local apa_cpa   = 3.5734  * wc.m;
local cpa_thick = 3.175   * wc.mm;  // 1/8", confirmed with LArSoft
local apa_w2w   = 85.87   * wc.mm;
local plane_gap = 4.76    * wc.mm;
local apa_g2g   = apa_w2w + 6 * plane_gap;

// Anode cut-off: at the first induction wires (innermost plane)
local apa_plane = 0.5 * apa_g2g - plane_gap;

// Response plane: distance from collection wires where Garfield calculations start.
// MUST match the field response files used.
local response_plane = 10 * wc.cm;
local res_plane      = 0.5 * apa_w2w + response_plane;

// Cathode cut-off
local cpa_plane = apa_cpa - 0.5 * cpa_thick;

// ---------------------------------------------------------------------------
// Default electronics gain.  Override via params.elec_gain.
// Two standard values in use at PDHD: 14 mV/fC and 7.8 mV/fC.
// ---------------------------------------------------------------------------
local elec_gain = std.get(params, "elec_gain", 14.0) * wc.mV / wc.fC;

// SP Wiener-filter set (xerosere ddm-3bu.9).  "native" (default) keeps the
// production-faithful (broad) PDHD Wiener_tight filters (tuned for np04hd +
// DNNROI).  "narrow" swaps in the PDSP-tuned narrow Wiener for the bare-
// OmnibusSigProc path, which otherwise floods the U/V induction planes with
// noise ROIs.  See sp-filters-narrow.jsonnet.
local sp_wiener = std.get(params, "sp_wiener", "native");

// ---------------------------------------------------------------------------
// Assemble per-anode entries
// ---------------------------------------------------------------------------
local make_anode(n) =
    local sign      = 2 * (n % 2) - 1;  // APA0,2 → -1; APA1,3 → +1
    local centerline = sign * apa_cpa;
    {
        ident: n,
        name: "apa%d" % n,

        // Both faces active (sim-mode geometry).
        // Face 0 is the "positive" face (higher X); face 1 is the "negative" face.
        // For APA0/2 (sign=-1): face0 is toward cathode side, face1 is toward cryo wall.
        // For APA1/3 (sign=+1): face0 is toward cryo wall, face1 is toward cathode side.
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

        // Electronics response.
        // All PDHD APAs use ColdElecResponse with the same parameters.
        elec: {
            type:     "ColdElecResponse",
            gain:     elec_gain,
            shaping:  2.2 * wc.us,
            postgain: 1.0,
        },

        // Field response file.
        // APA0 uses a higher-quality 6-path MCMC best-fit response.
        // APAs 1-3 use the generic DUNE 1D response.
        field: {
            filename: if n == 0
                then "np04hd-garfield-6paths-mcmc-bestfit.json.bz2"
                else "dune-garfield-1d565.json.bz2",
            // Distance from the collection plane where this file's paths start.
            response_plane: response_plane,
        },

        // Optional frequency-domain filter response for SP deconvolution correction.
        // Only applied to APA0 (the one with the special field response).
        filter_response: if n == 0
            then { filename: "protodunehd-field-response-filters.json.bz2" }
            else null,

        // Noise spectra.  File depends on the FE amplifier gain setting.
        noise: {
            filename: if elec_gain > 8 * wc.mV / wc.fC
                then "protodunehd-noise-spectra-14mVfC-v1.json.bz2"
                else "protodunehd-noise-spectra-7d8mVfC-v1.json.bz2",
            wire_length_scale: 1.0 * wc.cm,
        },

        // ADC / digitizer settings.
        // Uniform across all PDHD APAs.
        adc: {
            resolution: 14,
            gain:       1.0,
            baselines:  [1003.4 * wc.mV, 1003.4 * wc.mV, 507.7 * wc.mV],
            fullscale:  [0.2 * wc.volt, 1.6 * wc.volt],
        },

        // OmnibusSigProc tuning.
        // APA0 differs from APAs 1-3 in: plane2layer and Wiener filter names.
        //
        // NOTE on troi_col_th_factor (xerosere ddm-3bu.9):
        // The toolkit pgrapher/experiment/pdhd/sp.jsonnet uses
        //   troi_col_th_factor = 5.0  (its comment: "// default 5").
        // An earlier transcription here used 2.5 (with a comment that
        // misquoted the toolkit as 2.5).  2.5 sigma tight-ROI finding on the
        // collection plane floods the W plane with noise ROIs: on a single
        // ideal line in APA0, W collection gave 32491 gauss ROIs at 2.5 vs
        // 216 (real signal only) at 5.0.  Use the toolkit value 5.0.
        //
        // (Induction troi_ind_th_factor=3.0 already matches the toolkit.  The
        // toolkit APA0 additionally lowers r_th_factor to 2.5 and enables the
        // permissive APA0 W ROI-tune / roi_mad_rms / L1SPFilterPD to recover
        // the anomalous APA0 W signal; those RAISE ROI count and are
        // intentionally NOT reproduced by this bare-OSP config.)
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
            // Wire plane ordering fed into the SP deconvolution kernel.
            // APA0 uses [0,2,1] (U,W,V); others use standard [0,1,2] (U,V,W).
            plane2layer: if n == 0 then [0, 2, 1] else [0, 1, 2],
            // Wiener filter instance names (hard-coded in OmnibusSigProc C++).
            // APA0 uses the "APA1-variant" names which have different tuning values
            // appropriate for the higher-quality 6-path MCMC field response.
            wiener_filters: if n == 0
                then ["Wiener_tight_U_APA1", "Wiener_tight_V_APA1", "Wiener_tight_W_APA1"]
                else ["Wiener_tight_U",      "Wiener_tight_V",      "Wiener_tight_W"],
        },
    };

// ---------------------------------------------------------------------------
// Defaults (override via params.{lar,daq,sim})
// ---------------------------------------------------------------------------
local lar_defaults = {
    DL:          7.2  * wc.cm2 / wc.s,
    DT:          12.0 * wc.cm2 / wc.s,
    lifetime:    8    * wc.ms,
    drift_speed: 1.6  * wc.mm / wc.us,
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
    name: "pdhd",

    daq: daq,
    lar: lar,
    sim: sim,

    wires: {
        filename: "protodunehd-wires-larsoft-v1.json.bz2",
    },

    // Drift planes from geometry (GDML via Phlex): the same anode cut as the
    // faces above (first induction plane, apa_plane - apa_w2w/2 = 9.52 mm
    // from the collection plane), and both faces of an APA active with the
    // same drift length: the GDML's outer (wall side) TPCs are only ~2.5 cm,
    // less than the 10 cm response distance.
    drift_planes: {
        anode_offset: apa_plane - 0.5 * apa_w2w,
        short_drift: "mirror",
    },

    // 4 APAs: apa0 .. apa3
    anodes: [make_anode(n) for n in std.range(0, 3)],

    // SP filter components (detector-tuned; names hard-coded in C++)
    sp_filters: if sp_wiener == "narrow"
        then import "sp-filters-narrow.jsonnet"
        else import "sp-filters.jsonnet",

    // Optional response systematics (off by default; sys_status defaults false)
    sys_resp: {
        start:      -10 * wc.us,
        magnitude:  1.0,
        time_smear: 1.0 * wc.us,
    },
    rc_resp: {
        width:     1.1 * wc.ms,
        rc_layers: 0,
    },

    // DepoFluxSplat parameters.
    // smear_long and smear_tran represent the extra longitudinal / transverse
    // spread that the full sim+SP chain induces beyond pure charge flux.
    // Values are per wire-plane: [U, V, W].
    // Determined empirically via "wcpy gen morse-*"; PDHD reuses PDSP values
    // (same field-response family).
    // The splat window (tick, start, duration) is derived per anode from its
    // field.response_plane in job/parts.jsonnet.
    splat: {
        sparse:          true,
        reference_time:  0.0,
        smear_long: [2.691862363980221, 2.6750200122535057, 2.7137567141154055],
        smear_tran: [0.7377218875719689, 0.7157764520393882, 0.13980698710556544],
    },

    // Overall detector bounding box (informational; for kinematics generators etc.)
    bounds: {
        tail: wc.point(-4.0, 0.0, 0.0, wc.m),
        head: wc.point(+4.0, 6.1, 7.0, wc.m),
    },
});

// ---------------------------------------------------------------------------
// Variant selection (beads ddm-4pz.13).
//
//   ideal -- the base description (all four APAs nominal).
//   real  -- the as-built PDHD: APA0 carries an altered/degraded field
//            response.  Ideal APA0 uses the idealized MCMC best-fit response
//            (np04hd-garfield-6paths-mcmc-bestfit); the as-built APA0 uses the
//            plain measured 6-path Garfield response (np04hd-garfield-6paths,
//            also shipped in wire-cell-data/pdhd).  Only anodes[0].field
//            changes; the other three APAs and every other APA0 field are
//            untouched -- the whole point of the overlay mechanism.
//
// NOTE (confirm with detector experts): this encodes the pathology purely as a
// field-response swap.  Whether APA0's SP filter_response correction
// (protodunehd-field-response-filters, tuned for the best-fit response) and its
// APA1-variant Wiener names should ALSO change for the as-built response is a
// physics question left open; the overlay touches only field.filename for now.
// ---------------------------------------------------------------------------
local variants = {
    ideal: base,
    real: variant.patch_anodes(base, {
        "0": { field: { filename: "np04hd-garfield-6paths.json.bz2" } },
    }),
};

local vname = variant.select(params);
assert std.objectHas(variants, vname)
       : "pdhd: unknown variant '" + vname + "' (have: "
         + std.join(", ", std.objectFields(variants)) + ")";

variants[vname]
