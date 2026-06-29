// cfg/dune/wct/job/parts.jsonnet
//
// Single source of every WCT component (inode) used by the DUNE sim/sigproc/
// splat job builders.  Centralizing the {type,name,data} definitions here is
// what lets the job builders (sim/sigproc/sim-sigproc/splat) COMPOSE pnodes
// instead of each re-declaring the same components -- the duplication that had
// already let the old hand-written sim.jsonnet and sim-sigproc.jsonnet drift
// apart (different DepoTransform rng / PIR padding).
//
//   parts(detector, anode_index, service_prefix, variant) -> { inodes... }
//
// Service/helper inodes (dft, rng, wires, fr, elec, anode, pirs, drifter,
// noise_model, ...) are built ONCE here.  Each job builder references the same
// objects, so graph.application()/pg.uses() de-duplicates them to exactly one
// instance even in the combined sim+sigproc graph.
//
// Returns hidden (::) fields; job builders read them as P.<name>.

local wc   = import "wirecell.jsonnet";
local dets = import "dune/wct/detectors.jsonnet";

function(detector="pdhd", anode_index="0", service_prefix="", variant="ideal")

local det = dets[detector]({ detname: detector, variant: variant });
local ai  = std.parseInt(anode_index);
local a   = det.anodes[ai];
local pfx = service_prefix;

// --- derived timing ---------------------------------------------------------
local tick            = det.daq.tick;
local nticks_daq      = det.daq.nticks;
local response_nticks = wc.roundToInt(det.response_plane / det.lar.drift_speed / tick);
local nticks_ductor   = nticks_daq + response_nticks;
local readout_time    = nticks_ductor * tick;
local start_time      = det.sim.tick0_time - det.response_plane / det.lar.drift_speed;

// --- shared service inodes --------------------------------------------------
local dft = {
    type: "FftwDFT",
    name: pfx + "dft_" + a.name,
    data: {},
};

local rng = {
    type: "Random",
    name: pfx + "rng_" + a.name,
    data: { seed: 1 },   // fixed seed for reproducible noise
};

local wires = {
    type: "WireSchemaFile",
    name: pfx + "wires_" + a.name,
    data: { filename: det.wires.filename },
};

local fr = {
    type: "FieldResponse",
    name: pfx + "fr_" + a.name,
    data: { filename: a.field.filename },
};

// Electronics response (polymorphic: ColdElecResponse or JsonElecResponse).
local elec = {
    type: a.elec.type,
    name: pfx + "elec_" + a.name,
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

local anode = {
    type: "AnodePlane",
    name: pfx + a.name,
    data: {
        ident:       a.ident,
        nimpacts:    det.sim.nimpacts,
        wire_schema: wc.tn(wires),
        faces:       a.faces,
    },
};

// PIR short padding must exceed the full field-response duration; 2x the drift
// transit time safely covers both PDHD (100us) and PDVD (132.5us).
local pir_short_padding = det.response_plane / det.lar.drift_speed * 2.0;

local pir(plane) = {
    type: "PlaneImpactResponse",
    name: pfx + "pir%d_" % plane + a.name,
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
};
local pirs = [pir(p) for p in [0, 1, 2]];

// --- sim-stage inodes -------------------------------------------------------
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
        xregions:    a.faces,
    },
};

local setdrifter = {
    type: "DepoSetDrifter",
    name: pfx + "deposet_drifter_" + a.name,
    data: { drifter: wc.tn(drifter_comp) },
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
    },
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
};

// --- splat-stage inode ------------------------------------------------------
local splat = {
    type: "DepoFluxSplat",
    name: pfx + "splat_" + a.name,
    data: det.splat + {
        anode:          wc.tn(anode),
        field_response: wc.tn(fr),   // only period and origin are used
    },
};

// --- sigproc-stage inodes ---------------------------------------------------
local adc_range = a.adc.fullscale[1] - a.adc.fullscale[0];
local adc_mv    = ((1 << a.adc.resolution) - 1.0) / adc_range;

local has_filter_response = a.filter_response != null;
local filter_response_comps = if has_filter_response then [
    {
        type: "FilterResponse",
        name: pfx + "fltresp_" + a.name + "_" + plane,
        data: {
            filename: a.filter_response.filename,
            plane:    plane,
            wires:    wc.tn(wires),
        },
    }
    for plane in [0, 1, 2]
] else [];
local filter_response_tns =
    [wc.tn(filter_response_comps[p]) for p in std.range(0, std.length(filter_response_comps) - 1)];

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
};

// ---------------------------------------------------------------------------
{
    det:: det,
    a:: a,
    ai:: ai,
    timing:: {
        tick: tick, nticks_daq: nticks_daq, response_nticks: response_nticks,
        nticks_ductor: nticks_ductor, readout_time: readout_time, start_time: start_time,
    },

    // service / helper inodes (non-wired: referenced by name)
    dft:: dft,
    rng:: rng,
    wires:: wires,
    fr:: fr,
    elec:: elec,
    anode:: anode,
    pirs:: pirs,
    drifter_comp:: drifter_comp,
    noise_model:: noise_model,
    filter_response_comps:: filter_response_comps,
    sp_filters:: det.sp_filters,

    // stage inodes (wired into the graph by the job builders)
    setdrifter:: setdrifter,
    transform:: transform,
    reframer:: reframer,
    addnoise:: addnoise,
    digitizer:: digitizer,
    splat:: splat,
    sigproc:: sigproc,
}
