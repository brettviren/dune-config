// cfg/dune/wct/detectors/pdvd/detector.jsonnet
//
// ProtoDUNE-VD (PDVD) detector description for dune-config.
//
// Returns a plain-data detector description (see dune/wct/lib/schema.jsonnet).
// No WCT component configs are embedded here except sp_filters.  WCT component
// construction happens in dune/wct/job/*.jsonnet functions that consume this.
//
// PDVD has vertical drift with 8 anodes: anodes 0-3 are "bottom drift" and
// anodes 4-7 are "top drift".  Bottom and top differ in electronics type
// (ColdElecResponse vs JsonElecResponse), ADC settings, and noise spectra --
// exercising the schema's polymorphic elec and per-anode variation.
//
// Geometry source: protodunevd geometry (see wirecell-util wire-volumes).
// Transcribed from dunereco/DUNEWireCell/protodunevd/{params,simparams}.jsonnet
// (via wire-cell-phlex/cfg/dune/wct/dets/pdvd/detector.jsonnet).
//
// Face geometry: always sim-mode (both faces active per anode).
//
// Arguments:
//   params: override object.  params.detname = "pdvd".
//           params.variant selects a variant overlay (default "ideal").
//           Optional fields (merged): lar, daq, sim.
//           Example: {detname:"pdvd", lar:{lifetime: 1000*wc.ms}}

local wc      = import "wirecell.jsonnet";
local schema  = import "../../lib/schema.jsonnet";
local variant = import "../../lib/variant.jsonnet";

function(params={detname: "pdvd"})

// ---------------------------------------------------------------------------
// Geometry constants
// ---------------------------------------------------------------------------
// CRP geometry per X. Ning's review of the PDVD Wire-Cell config (dunereco
// fix/pdvd-crp-drift-planes, "NP02 bias study"; xero
// topics/wcls-wires/work/notes-from-pdvd-fix/DUNERECO_DRIFT_PLANE_FIX.md).
// A CRP is one-sided: apa_cpa is the x of the W (collection) strips, not an
// APA center line, so no APA half-width enters (the old 0.5*apa_w2w put the
// response plane 4.29 cm too far from W: hits 4.29 cm too close to the anode).

// |x| of the W strips (the cathode is at x = 0).
local apa_cpa   = 341.55 * wc.cm;
// Cathode block thickness in the PDVD GDML.
local cpa_thick = 60.0   * wc.mm;

// Anode cut-off: the CRP shield plane, where the active LAr ends, 16.4 mm
// from W toward the cathode (W -3.2 mm- V -10 mm- U -3.2 mm- shield).
local apa_plane = 16.4 * wc.mm;

// Response plane: distance from the W strips where the field response starts
// (its "origin", 181 mm in protodunevd_FR_norminal_260324).
local response_plane = 18.1 * wc.cm;

// The field response's drift speed ("speed", 1.53 mm/us in the same file);
// the MC ctoffset below corrects for the simulated speed differing from it.
local fr_speed = 1.53 * wc.mm / wc.us;
local drift_speed = 1.473 * wc.mm / wc.us;  // data-driven PDVD value (lar below)

// Cathode cut-off: |x| of the cathode surface.
local cpa_plane = 0.5 * cpa_thick;

// ---------------------------------------------------------------------------
// Per-anode entry builder
// ---------------------------------------------------------------------------
local make_anode(a) =
    // Anodes 0-3: bottom drift (sign=-1, drift in -Y direction)
    // Anodes 4-7: top drift    (sign=+1, drift in +Y direction)
    local sign       = if a > 3 then 1 else -1;
    local centerline = sign * apa_cpa;
    {
        ident: a,
        name: "anode%d" % a,

        // Both faces active, the same: the two faces of a WCT anode are the
        // two halves (TPCs) of a CRU, in the same drift volume.
        //
        // Coordinate note: the PDVD wire file maps physical Y (vertical drift axis)
        // to WCT X.  Anodes 0-3 sit at negative X (bottom CRPs), anodes 4-7 at
        // positive X (top CRPs), and the cathode is at X=0 (center).
        //
        // |x| of the planes: anode cut-off 339.91 cm, response plane 323.45 cm,
        // cathode 3.0 cm.
        local face = {
            anode:    centerline - sign * apa_plane,
            response: centerline - sign * response_plane,
            cathode:  sign * cpa_plane,
        },
        faces: [ face, face ],

        // Electronics response.
        // Bottom drift (a < 4): standard ColdElecResponse
        // Top drift    (a >= 4): JsonElecResponse loaded from file
        elec: if a < 4 then {
            type:     "ColdElecResponse",
            gain:     7.8 * wc.mV / wc.fC,
            shaping:  2.2 * wc.us,
            postgain: 1.1365,
        } else {
            type:     "JsonElecResponse",
            filename: "dunevd-coldbox-elecresp-top-psnorm_400.json.bz2",
            postgain: 1.52,
        },

        // Field response file.
        // Both bottom and top drift use the same nominal PDVD field response.
        field: {
            filename: "protodunevd_FR_norminal_260324.json.bz2",
            // Distance from the collection plane where this file's paths start.
            response_plane: response_plane,
        },

        // No frequency-domain filter response for PDVD.
        filter_response: null,

        // Noise spectra.  Different files for bottom and top drift.
        noise: {
            filename: if a < 4
                then "pdvd-bottom-noise-spectra-v1.json.bz2"
                else "pdvd-top-noise-spectra-v2.json.bz2",
            wire_length_scale: 1.0 * wc.cm,
        },

        // ADC / digitizer settings.
        // Bottom and top drift use different baselines and fullscale ranges.
        adc: {
            resolution: 14,
            gain:       1.0,
            baselines: if a < 4
                then [1003.4 * wc.mV, 1003.4 * wc.mV, 507.7 * wc.mV]
                else [1.0 * wc.volt,  1.0 * wc.volt,  1.0 * wc.volt],
            fullscale: if a < 4
                then [0.2 * wc.volt, 1.6 * wc.volt]
                else [0.0 * wc.volt, 2.0 * wc.volt],
        },

        // OmnibusSigProc tuning.
        // ctoffset: simulation value (X. Ning's review): the field response
        // assumes fr_speed from response_plane on, so the arrival time is off
        // by response_plane/drift_speed - response_plane/fr_speed (+4.58 us at
        // 1.473 mm/us).  Data keeps the tuned 4 us (no "real" variant yet).
        // Multi-plane protection; otherwise similar to PDHD.
        //
        // troi_col_th_factor lowered 5.0 -> 2.5 (xerosere ddm-tv6): the PDVD CRP
        // collection electrode (strips on stacked PCBs with thru-hole "loop-back"
        // collection) has a physically BROAD field response -- ~2-8x wider than a
        // PDHD/PDSP collection (see tests/fr-path-sums.py), so the deconvolved
        // collection is low-amplitude.  At the production 5.0 sigma the collection
        // tight-ROI finder produced NO collection output at all (W plane empty ->
        // 3-view tiling found 0 blobs).  A threshold scan (norminal FR, single
        // ideal line) recovers the collection: 5.0->0, 3.0->270, 2.5->416,
        // 2.0->819 W-plane ROI traces/event; 2.5 recovers the plane at the best
        // imaging (27 img_sp blobs) with less added noise than 2.0.  Production
        // dunereco keeps 5.0 because it uses DNNROI, not this bare-OSP ROI finder.
        // PROVISIONAL pending FR/response review with the detector experts.
        sigproc: {
            ctoffset:    response_plane / drift_speed - response_plane / fr_speed,
            ftoffset:    0.0,
            postgain:    1.0,
            fft_flag:    0,
            troi_col_th_factor: 2.5,
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
            use_multi_plane_protection: true,
            isWrapped:    false,
            sparse:       true,
            // Standard plane ordering
            plane2layer:    [0, 1, 2],
            wiener_filters: ["Wiener_tight_U", "Wiener_tight_V", "Wiener_tight_W"],
        },
    };

// ---------------------------------------------------------------------------
// Defaults (override via params.{lar,daq,sim})
// ---------------------------------------------------------------------------
local lar_defaults = {
    DL:          4.0   * wc.cm2 / wc.s,
    DT:          8.8   * wc.cm2 / wc.s,
    lifetime:    1000.0 * wc.ms,
    drift_speed: drift_speed,
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
    name: "pdvd",

    daq: daq,
    lar: lar,
    sim: sim,

    wires: {
        filename: "protodunevd-wires-larsoft-v3.json.bz2",
    },

    // Drift planes from geometry (GDML via Phlex): the same anode cut-off as
    // the faces above (the shield plane, apa_plane from W); the response
    // plane is response_plane from W.
    drift_planes: {
        anode_offset: apa_plane,
    },

    // 8 anodes: anode0..anode3 (bottom drift), anode4..anode7 (top drift)
    anodes: [make_anode(a) for a in std.range(0, 7)],

    // SP filter components (PDVD-tuned; names hard-coded in C++)
    sp_filters: import "sp-filters.jsonnet",

    // Optional response systematics (off by default; sys_status defaults false)
    sys_resp: {
        start:      0 * wc.us,
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
    // No empirically derived values exist for PDVD yet (requires "wcpy gen morse-*").
    // Using zeros for now (conservative: splat truth is tighter than SP output).
    // The splat window (tick, start, duration) is derived per anode from its
    // field.response_plane in job/parts.jsonnet.
    splat: {
        sparse:          true,
        reference_time:  0.0,
        smear_long: [0.0, 0.0, 0.0],
        smear_tran: [0.0, 0.0, 0.0],
    },

    // Overall detector bounding box (informational)
    bounds: {
        tail: wc.point(-3.15, -3.42, 0.0,  wc.m),
        head: wc.point( 3.13,  3.42, 3.04, wc.m),
    },
});

// ---------------------------------------------------------------------------
// Variant selection.  Only "ideal" (the base) exists today.
// ---------------------------------------------------------------------------
local variants = {
    ideal: base,
};

variants[variant.select(params)]
