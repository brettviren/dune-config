// cfg/dune/wct/lib/schema.jsonnet
//
// The detector-description schema: structural defaults + validate().
//
// A detector description is a PLAIN-DATA object (no WCT {type,name,data}
// components, except sp_filters which carry C++-hard-coded names).  Job
// builders under dune/wct/job/ consume it.  This file deliberately holds NO
// physics values or units -- only STRUCTURE (which fields must exist and their
// JSON types) and unit-free structural defaults -- so it imports nothing and
// the authoritative values stay in the per-detector files under
// dune/wct/detectors/.
//
// Use make(fields) to build a detector: it applies structural defaults and then
// validate()s.  See dune/wct/lib/variant.jsonnet for variant overlays and
// dune/wct/detectors.jsonnet for the registry.

{
    // Structural-only defaults (no units).  Applied by make().
    anode_structural_defaults:: {
        // Optional SP deconvolution-correction file; absent on most anodes.
        filter_response: null,
    },
    detector_structural_defaults:: {
        // Response systematics off unless a detector opts in.
        sys_status: false,
    },

    // Electronics-response types and the fields each one needs.  The anode's
    // elec object is polymorphic: bottom and top drift volumes of a vertical
    // drift detector have different front-end electronics, so each anode
    // names its own type.  Extend this table when a new type is used, and
    // job/parts.jsonnet which turns it into a WCT component.
    elec_fields:: {
        ColdElecResponse: { gain: 'number', shaping: 'number', postgain: 'number' },
        JsonElecResponse: { filename: 'string', postgain: 'number' },
    },

    validate_elec(e, ctx)::
        assert std.objectHas($.elec_fields, e.type)
               : ctx + ".type '" + e.type + "' unknown (have: "
                 + std.join(", ", std.objectFields($.elec_fields)) + ")";
        local need = $.elec_fields[e.type];
        local bad = [k for k in std.objectFields(need)
                     if !(std.objectHas(e, k) && std.type(e[k]) == need[k])];
        assert bad == [] : ctx + " (" + e.type + ") needs " + std.join(", ", [
            k + ":" + need[k] for k in bad]);
        true,

    // OmnibusSigProc tuning keys every anode's sigproc must give (read by
    // job/parts.jsonnet).
    sigproc_keys:: [
        'ctoffset', 'ftoffset', 'postgain', 'fft_flag',
        'troi_col_th_factor', 'troi_ind_th_factor',
        'lroi_rebin', 'lroi_th_factor', 'lroi_th_factor1', 'lroi_jump_one_bin',
        'r_th_factor', 'r_fake_signal_low_th', 'r_fake_signal_high_th',
        'r_fake_signal_low_th_ind_factor', 'r_fake_signal_high_th_ind_factor',
        'r_th_peak', 'r_sep_peak', 'r_low_peak_sep_threshold_pre',
        'use_roi_debug_mode', 'use_multi_plane_protection', 'isWrapped', 'sparse',
        'plane2layer', 'wiener_filters',
    ],

    // Validate one anode entry; returns true or raises.  `ctx` is a label used
    // in error messages.
    validate_anode(a, ctx)::
        assert std.isObject(a) : ctx + " must be an object";
        assert std.objectHas(a, 'ident') && std.isNumber(a.ident)
               : ctx + ".ident must be a number";
        assert std.objectHas(a, 'name') && std.isString(a.name)
               : ctx + ".name must be a string";
        assert std.objectHas(a, 'faces') && std.isArray(a.faces)
               : ctx + ".faces must be an array";
        assert std.objectHas(a, 'elec') && std.isObject(a.elec)
               && std.objectHas(a.elec, 'type') && std.isString(a.elec.type)
               : ctx + ".elec must be an object with a string .type";
        assert $.validate_elec(a.elec, ctx + ".elec");
        // The response plane is a property of the field-response file (the
        // distance from the collection plane where its paths start), so it
        // lives with the file, per anode: anodes with different field
        // responses may have different response planes.
        assert std.objectHas(a, 'field') && std.isObject(a.field)
               && std.objectHas(a.field, 'filename') && std.isString(a.field.filename)
               && std.objectHas(a.field, 'response_plane') && std.isNumber(a.field.response_plane)
               : ctx + ".field needs {filename:string, response_plane:number}";
        assert std.objectHas(a, 'filter_response')
               : ctx + ".filter_response must be present (an object or null)";
        assert std.objectHas(a, 'noise') && std.isObject(a.noise)
               && std.isString(a.noise.filename) && std.isNumber(a.noise.wire_length_scale)
               : ctx + ".noise needs {filename:string, wire_length_scale:number}";
        assert std.objectHas(a, 'adc') && std.isObject(a.adc)
               && std.isNumber(a.adc.resolution) && std.isNumber(a.adc.gain)
               && std.isArray(a.adc.baselines) && std.length(a.adc.baselines) == 3
               && std.isArray(a.adc.fullscale) && std.length(a.adc.fullscale) == 2
               : ctx + ".adc needs {resolution:number, gain:number, baselines:[3], fullscale:[2]}";
        assert std.objectHas(a, 'sigproc') && std.isObject(a.sigproc)
               : ctx + ".sigproc must be an object";
        local missing = [k for k in $.sigproc_keys if !std.objectHas(a.sigproc, k)];
        assert missing == [] : ctx + ".sigproc lacks " + std.join(", ", missing);
        assert std.isArray(a.sigproc.plane2layer) && std.length(a.sigproc.plane2layer) == 3
               && std.isArray(a.sigproc.wiener_filters) && std.length(a.sigproc.wiener_filters) == 3
               : ctx + ".sigproc.{plane2layer,wiener_filters} must have 3 entries";
        true,

    // Validate a whole detector description; returns it unchanged or raises.
    // Checks structure/type, not physics values.
    validate(det)::
        assert std.objectHas(det, 'name') && std.isString(det.name)
               : "detector.name must be a string";
        assert std.objectHas(det, 'daq') && std.isObject(det.daq)
               && std.isNumber(det.daq.tick) && std.isNumber(det.daq.nticks)
               : det.name + ".daq needs {tick:number, nticks:number}";
        assert std.objectHas(det, 'lar') && std.isObject(det.lar)
               && std.isNumber(det.lar.DL) && std.isNumber(det.lar.DT)
               && std.isNumber(det.lar.lifetime) && std.isNumber(det.lar.drift_speed)
               : det.name + ".lar needs {DL,DT,lifetime,drift_speed} numbers";
        assert std.objectHas(det, 'sim') && std.isObject(det.sim)
               && std.isNumber(det.sim.tick0_time) && std.isNumber(det.sim.nsigma)
               && std.isNumber(det.sim.nimpacts)
               : det.name + ".sim needs {tick0_time,nsigma,nimpacts} (+fluctuate)";
        assert !std.objectHas(det, 'response_plane')
               : det.name + ": response_plane moved to anodes[].field.response_plane";
        assert std.objectHas(det, 'wires') && std.isObject(det.wires)
               && std.isString(det.wires.filename)
               : det.name + ".wires.filename must be a string";
        assert std.objectHas(det, 'anodes') && std.isArray(det.anodes)
               && std.length(det.anodes) > 0
               : det.name + ".anodes must be a non-empty array";
        assert std.objectHas(det, 'sp_filters') && std.isArray(det.sp_filters)
               : det.name + ".sp_filters must be an array";
        // DepoFluxSplat settings that are not derived from timing.  The
        // window (start, duration) follows from each anode's response plane
        // and is computed in job/parts.jsonnet, so it is not given here.
        assert std.objectHas(det, 'splat') && std.isObject(det.splat)
               && std.isBoolean(det.splat.sparse) && std.isNumber(det.splat.reference_time)
               && std.isArray(det.splat.smear_long) && std.length(det.splat.smear_long) == 3
               && std.isArray(det.splat.smear_tran) && std.length(det.splat.smear_tran) == 3
               && !std.objectHas(det.splat, 'window_start')
               && !std.objectHas(det.splat, 'window_duration')
               && !std.objectHas(det.splat, 'tick')
               : det.name + ".splat needs {sparse, reference_time, smear_long[3], smear_tran[3]}"
                 + " and no window_start/window_duration/tick (derived per anode)";
        assert std.all([
                   $.validate_anode(det.anodes[i], det.name + ".anodes[" + i + "]")
                   for i in std.range(0, std.length(det.anodes) - 1)
               ])
               : det.name + ": anode validation failed";
        det,

    // Build a detector description: apply structural defaults, then validate.
    // `fields` is the full description minus the structural defaults.
    make(fields)::
        local det = $.detector_structural_defaults + fields + {
            anodes: [$.anode_structural_defaults + a for a in fields.anodes],
        };
        $.validate(det),
}
