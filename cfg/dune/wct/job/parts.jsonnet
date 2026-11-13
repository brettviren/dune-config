// cfg/dune/wct/job/parts.jsonnet
//
// Single source of every WCT component (inode) used by the DUNE sim/sigproc/
// splat job builders.  Centralizing the {type,name,data} definitions here is
// what lets the job builders (sim/sigproc/sim-sigproc/splat) COMPOSE pnodes
// instead of each re-declaring the same components.
//
//   parts(detector, anode_index, service_prefix, variant, geometry) -> { stage inodes... }
//
// geometry selects where the wires and drift planes come from:
//   "file"  : det.wires.filename (WireSchemaFile) and each anode's "faces".
//   "phlex" : Phlex job-layer products (e.g. made from GDML by the
//             wcph_gdml_geometry transforms) given to WCT by the executor:
//             FacadeWireSchema and FacadeDriftPlanes (wire-cell-phlex), with
//             the drift planes computed from the geometry and the anode's
//             response_plane.  The executor's module needs a "geometry"
//             config (see dune/phlex/workflow.jsonnet).
//
// DEPENDENCY DECLARATION via `.uses`:
//   Every inode that references another component (by wc.tn in its data, or by
//   hard-coded name like OmnibusSigProc's SP filters) carries a `.uses` list of
//   those components.  A service component likewise carries its own `.uses`
//   (e.g. AnodePlane uses the WireSchemaFile).  pgraph's uses()/resolve_uses()
//   then TOPOLOGICALLY SORTS the whole dependency graph, so a service is always
//   emitted -- and therefore configured -- before any client that uses it.
//   This is what guarantees, e.g., AnodePlane is configured before OmnibusSigProc
//   (which walks the anode in its configure()); see [[wct-config-order-sigproc]].
//   pgraph strips `.uses` before the component reaches the WCT config sequence.
//
//   Consequence: the job builders only need to wire the STAGE inodes into a
//   pipeline; the services they (transitively) use are pulled in and ordered
//   automatically by pg.uses().  No manual service list is needed.
//
// SHARED SERVICES.  Services whose configuration does not depend on the anode
// (DFT, field response, electronics response, plane impact responses) are
// named by their content: service_prefix + a label + a hash of their data
// (shared_name below).  Two anodes, or two WCT islands (Mains) of one Phlex
// job, that need the same service therefore name the same WCT instance: WCT's
// NamedFactory hands both the one object, and WCT Main configures it once
// (a later Main skips an identically configured component and refuses a
// differently configured one).  These components are read-only after
// configure (FftwDFT guards its plan cache), so concurrent islands may share
// them.  Per-anode state (anode, RNG, noise model, sim/sigproc stages) keeps
// per-anode names.

local wc   = import "wirecell.jsonnet";
local dets = import "dune/wct/detectors.jsonnet";

function(detector="pdhd", anode_index="0", service_prefix="", variant="ideal", geometry="file")

assert geometry == "file" || geometry == "phlex" : 'geometry must be "file" or "phlex", got "%s"' % geometry;

local det = dets[detector]({ detname: detector, variant: variant });
local ai  = std.parseInt(anode_index);
local a   = det.anodes[ai];
local pfx = service_prefix;

// --- derived timing ---------------------------------------------------------
// The response plane belongs to this anode's field response (anodes of one
// detector may use different field responses), so timing is per anode.
local response_plane  = a.field.response_plane;
local tick            = det.daq.tick;
local nticks_daq      = det.daq.nticks;
local response_nticks = wc.roundToInt(response_plane / det.lar.drift_speed / tick);
local nticks_ductor   = nticks_daq + response_nticks;
local readout_time    = nticks_ductor * tick;
local start_time      = det.sim.tick0_time - response_plane / det.lar.drift_speed;

// Content-derived name of a shared service: identical data <=> same name.
local shared_name(label, data) =
    pfx + label + "-" + std.substr(std.md5(std.manifestJsonEx(data, "")), 0, 10);

// --- leaf service inodes (no dependencies) ----------------------------------
local dft = {
    type: "FftwDFT",
    name: shared_name("dft", self.data),
    data: {},
};

// Per anode: a Random is not safe to share between concurrent islands.
// Fixed, per-anode seeds: reproducible, and different noise and fluctuations
// on different anodes (anode ident 0 keeps WCT's default seeds).
local rng = {
    type: "Random",
    name: pfx + "rng_" + a.name,
    data: { generator: "default", seeds: [0, 0, 0, 0, a.ident] },
};

local geo_phlex = geometry == "phlex";

// With geometry "phlex" these two components are shared by every WCT island
// of the job (no prefix, identical data): the first Main configures them.
local wires = if geo_phlex then {
    type: "FacadeWireSchema",
    name: "geometry",
    data: { key: "geometry" },
} else {
    type: "WireSchemaFile",
    name: shared_name("wires", self.data),   // one load of the file per job
    data: { filename: det.wires.filename },
};

local drift_planes = {
    type: "FacadeDriftPlanes",
    name: "geometry",
    data: {
        key: "geometry",
        response_distance: response_plane,
        anode_offset: std.get(det, "drift_planes", {}).anode_offset,
        short_drift: std.get(det, "drift_planes", {}).short_drift,
    },
};

// Anode/Drifter drift-plane parameters: inline "faces"/"xregions" from the
// detector object, or the IDriftPlanes component.
local anode_drift = if geo_phlex then { drift_planes: wc.tn(drift_planes) } else { faces: a.faces };
local drifter_drift = if geo_phlex then { drift_planes: wc.tn(drift_planes) } else { xregions: a.faces };
local drift_uses = if geo_phlex then [drift_planes] else [];

local fr = {
    type: "FieldResponse",
    name: shared_name("fr", self.data),
    data: { filename: a.field.filename },
};

// Electronics response (polymorphic: ColdElecResponse or JsonElecResponse;
// the fields each type needs are checked by lib/schema.jsonnet elec_fields).
local elec = {
    type: a.elec.type,
    name: shared_name("elec", [self.type, self.data]),
    data: {
        tick:   tick,
        nticks: nticks_ductor,
    } + (
        if a.elec.type == "ColdElecResponse" then {
            shaping:  a.elec.shaping,
            gain:     a.elec.gain,
            postgain: a.elec.postgain,
        } else if a.elec.type == "JsonElecResponse" then {
            filename: a.elec.filename,
            postgain: a.elec.postgain,
        } else error "Unknown elec type: " + a.elec.type
    ),
};

// --- service inodes with dependencies ---------------------------------------
local anode = {
    type: "AnodePlane",
    name: pfx + a.name,
    data: {
        ident:       a.ident,
        nimpacts:    det.sim.nimpacts,
        wire_schema: wc.tn(wires),
    } + anode_drift,
    uses: [wires] + drift_uses,
};

// PIR short padding must exceed the full field-response duration; 2x the drift
// transit time safely covers PDHD (100us), PDVD (132.5us) and FDVD (113us).
local pir_short_padding = response_plane / det.lar.drift_speed * 2.0;

local pir(plane) = {
    type: "PlaneImpactResponse",
    name: shared_name("pir%d" % plane, self.data),
    data: {
        plane:                 plane,
        dft:                   wc.tn(dft),
        field_response:        wc.tn(fr),
        nticks:                nticks_ductor,
        tick:                  tick,
        short_responses:       [wc.tn(elec)],
        overall_short_padding: pir_short_padding,
        long_responses:        [],
        long_padding:          1.5 * wc.ms,
    },
    uses: [dft, fr, elec],
};
local pirs = [pir(p) for p in [0, 1, 2]];

local drifter_comp = {
    type: "Drifter",
    name: pfx + "drifter_" + a.name,
    data: {
        rng:         wc.tn(rng),
        DL:          det.lar.DL,
        DT:          det.lar.DT,
        lifetime:    det.lar.lifetime,
        drift_speed: det.lar.drift_speed,
        fluctuate:   det.sim.fluctuate,
    } + drifter_drift,
    uses: [rng] + drift_uses,
};

// --- detector-wide drift ----------------------------------------------------
// One Drifter over every drift region of the detector, for a job that drifts
// once ahead of its per-anode islands (dune/wct/job/drift.jsonnet; the art
// multi-sim likewise drifts once before its fanout).  The islands then take
// drifted depos (sim-sigproc drifted="yes") and select their anode's with
// depofilter.  Regions: every distinct face of the detector, or, with
// geometry "phlex", the drift planes' xregions (also all of them).
local distinct(xs) = std.foldl(function(acc, x) if std.member(acc, x) then acc else acc + [x], xs, []);
local all_faces = distinct(std.flattenArrays([an.faces for an in det.anodes]));

local rng_detector = {
    type: "Random",
    name: pfx + "rng_detector",
    data: { generator: "default", seeds: [0, 0, 0, 1, 0] },
};

local drifter_detector = {
    type: "Drifter",
    name: pfx + "drifter_detector",
    data: {
        rng:         wc.tn(rng_detector),
        DL:          det.lar.DL,
        DT:          det.lar.DT,
        lifetime:    det.lar.lifetime,
        drift_speed: det.lar.drift_speed,
        fluctuate:   det.sim.fluctuate,
    } + (if geo_phlex then { drift_planes: wc.tn(drift_planes) } else { xregions: all_faces }),
    uses: [rng_detector] + drift_uses,
};

local noise_model = {
    type: "EmpiricalNoiseModel",
    name: pfx + "noise_model_" + a.name,
    data: {
        anode:             wc.tn(anode),
        dft:               wc.tn(dft),
        chanstat:          "",
        spectra_file:      a.noise.filename,
        nsamples:          nticks_daq,
        period:            tick,
        wire_length_scale: a.noise.wire_length_scale,
    },
    uses: [anode, dft],
};

local has_filter_response = a.filter_response != null;
local filter_response_comps = if has_filter_response then [
    {
        type: "FilterResponse",
        name: shared_name("fltresp%d" % plane, self.data),
        data: {
            filename: a.filter_response.filename,
            plane:    plane,
            wires:    wc.tn(wires),
        },
        uses: [wires],
    }
    for plane in [0, 1, 2]
] else [];
local filter_response_tns =
    [wc.tn(filter_response_comps[p]) for p in std.range(0, std.length(filter_response_comps) - 1)];

// --- stage inodes (wired into the graph; carry their service deps via .uses) -
local setdrifter = {
    type: "DepoSetDrifter",
    name: pfx + "deposet_drifter_" + a.name,
    data: { drifter: wc.tn(drifter_comp) },
    uses: [drifter_comp],
};

local setdrifter_detector = {
    type: "DepoSetDrifter",
    name: pfx + "deposet_drifter_detector",
    data: { drifter: wc.tn(drifter_detector) },
    uses: [drifter_detector],
};

// Drifted depos of this anode only: those in its faces' sensitive volumes.
local depofilter = {
    type: "DepoSetFilter",
    name: pfx + "depofilter_" + a.name,
    data: { anode: wc.tn(anode) },
    uses: [anode],
};

// Hydra switch: DeposOrBust passes a non-empty depo set on port 0 (to the
// sim/sigproc work) and turns an empty one into an empty frame on port 1;
// FrameSync merges the two paths.  An anode without depos then costs nothing.
local deposorbust = {
    type: "DeposOrBust",
    name: pfx + "deposorbust_" + a.name,
    data: {},
};
local framesync = {
    type: "FrameSync",
    name: pfx + "framesync_" + a.name,
    data: {},
};

local transform = {
    type: "DepoTransform",
    name: pfx + "transform_" + a.name,
    data: {
        rng:                wc.tn(rng),
        anode:              wc.tn(anode),
        pirs:               [wc.tn(p) for p in pirs],
        dft:                wc.tn(dft),
        fluctuate:          det.sim.fluctuate,
        drift_speed:        det.lar.drift_speed,
        readout_time:       readout_time,
        start_time:         start_time,
        tick:               tick,
        nsigma:             det.sim.nsigma,
        first_frame_number: 0,
        // The frame names its event (the depo set's ident), also when a
        // hydra switch skips events with no depos for this anode.
        frame_ident:        "deposet",
    },
    uses: [rng, anode, dft] + pirs,
};

local reframer = {
    type: "Reframer",
    name: pfx + "reframer_" + a.name,
    data: {
        anode:   wc.tn(anode),
        tags:    [],
        fill:    0.0,
        tbin:    response_nticks,
        toffset: 0,
        nticks:  nticks_daq,
    },
    uses: [anode],
};

local addnoise = {
    type: "AddNoise",
    name: pfx + "addnoise_" + a.name,
    data: {
        rng:                    wc.tn(rng),
        dft:                    wc.tn(dft),
        model:                  wc.tn(noise_model),
        nsamples:               nticks_daq,
        replacement_percentage: 0.02,
    },
    uses: [rng, dft, noise_model],
};

local digitizer = {
    type: "Digitizer",
    name: pfx + "digitizer_" + a.name,
    data: {
        anode:      wc.tn(anode),
        resolution: a.adc.resolution,
        gain:       a.adc.gain,
        fullscale:  a.adc.fullscale,
        baselines:  a.adc.baselines,
    },
    uses: [anode],
};

local splat = {
    type: "DepoFluxSplat",
    name: pfx + "splat_" + a.name,
    // The window spans the same (extended) time as the ductor: it starts
    // response_plane/drift_speed before tick0_time and runs for the DAQ
    // window plus the response ticks.
    data: det.splat + {
        tick:            tick,
        window_start:    start_time,
        window_duration: readout_time,
        anode:          wc.tn(anode),
        field_response: wc.tn(fr),   // only period and origin are used
    },
    uses: [anode, fr],
};

local adc_range = a.adc.fullscale[1] - a.adc.fullscale[0];
local adc_mv    = ((1 << a.adc.resolution) - 1.0) / adc_range;

local sp = a.sigproc;
local sigproc = {
    type: "OmnibusSigProc",
    name: pfx + "sigproc_" + a.name,
    data: {
        anode:          wc.tn(anode),
        dft:            wc.tn(dft),
        field_response: wc.tn(fr),
        elecresponse:   wc.tn(elec),
        per_chan_resp:  "",
        filter_responses: filter_response_tns,
        ADC_mV:         adc_mv,
        ftoffset:       sp.ftoffset,
        ctoffset:       sp.ctoffset,
        postgain:       sp.postgain,
        fft_flag:       sp.fft_flag,
        troi_col_th_factor:               sp.troi_col_th_factor,
        troi_ind_th_factor:               sp.troi_ind_th_factor,
        lroi_rebin:                       sp.lroi_rebin,
        lroi_th_factor:                   sp.lroi_th_factor,
        lroi_th_factor1:                  sp.lroi_th_factor1,
        lroi_jump_one_bin:                sp.lroi_jump_one_bin,
        r_th_factor:                      sp.r_th_factor,
        r_fake_signal_low_th:             sp.r_fake_signal_low_th,
        r_fake_signal_high_th:            sp.r_fake_signal_high_th,
        r_fake_signal_low_th_ind_factor:  sp.r_fake_signal_low_th_ind_factor,
        r_fake_signal_high_th_ind_factor: sp.r_fake_signal_high_th_ind_factor,
        r_th_peak:                        sp.r_th_peak,
        r_sep_peak:                       sp.r_sep_peak,
        r_low_peak_sep_threshold_pre:     sp.r_low_peak_sep_threshold_pre,
        use_roi_debug_mode:               sp.use_roi_debug_mode,
        use_multi_plane_protection:       sp.use_multi_plane_protection,
        isWrapped:                        sp.isWrapped,
        sparse:                           sp.sparse,
        wiener_filter_tight_U: sp.wiener_filters[0],
        wiener_filter_tight_V: sp.wiener_filters[1],
        wiener_filter_tight_W: sp.wiener_filters[2],
        plane2layer: sp.plane2layer,
    },
    // anode/dft/fr/elec by wc.tn; filter_responses by tn; SP filters (LfFilter/
    // HfFilter) by hard-coded name -> all must be present + ordered, so list them.
    uses: [anode, dft, fr, elec] + filter_response_comps + det.sp_filters,
};

// ---------------------------------------------------------------------------
// Expose the STAGE inodes the job builders wire into pipelines.  Each carries
// its service dependencies via `.uses`, so pg.uses() pulls in + orders every
// referenced service automatically -- no separate service list to thread.
{
    det:: det,
    a:: a,
    ai:: ai,
    timing:: {
        response_plane: response_plane,
        tick: tick, nticks_daq: nticks_daq, response_nticks: response_nticks,
        nticks_ductor: nticks_ductor, readout_time: readout_time, start_time: start_time,
    },

    setdrifter:: setdrifter,
    setdrifter_detector:: setdrifter_detector,
    depofilter:: depofilter,
    deposorbust:: deposorbust,
    framesync:: framesync,
    transform:: transform,
    reframer:: reframer,
    addnoise:: addnoise,
    digitizer:: digitizer,
    splat:: splat,
    sigproc:: sigproc,
}
