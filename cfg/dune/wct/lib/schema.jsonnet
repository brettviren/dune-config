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
        assert std.objectHas(a, 'field') && std.isObject(a.field)
               && std.objectHas(a.field, 'filename') && std.isString(a.field.filename)
               : ctx + ".field.filename must be a string";
        assert std.objectHas(a, 'filter_response')
               : ctx + ".filter_response must be present (an object or null)";
        assert std.objectHas(a, 'noise') && std.isObject(a.noise)
               && std.isString(a.noise.filename) && std.isNumber(a.noise.wire_length_scale)
               : ctx + ".noise needs {filename:string, wire_length_scale:number}";
        assert std.objectHas(a, 'adc') && std.isObject(a.adc)
               && std.isNumber(a.adc.resolution)
               && std.isArray(a.adc.baselines) && std.isArray(a.adc.fullscale)
               : ctx + ".adc needs {resolution:number, baselines:[], fullscale:[]}";
        assert std.objectHas(a, 'sigproc') && std.isObject(a.sigproc)
               : ctx + ".sigproc must be an object";
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
        assert std.objectHas(det, 'response_plane') && std.isNumber(det.response_plane)
               : det.name + ".response_plane must be a number";
        assert std.objectHas(det, 'wires') && std.isObject(det.wires)
               && std.isString(det.wires.filename)
               : det.name + ".wires.filename must be a string";
        assert std.objectHas(det, 'anodes') && std.isArray(det.anodes)
               && std.length(det.anodes) > 0
               : det.name + ".anodes must be a non-empty array";
        assert std.objectHas(det, 'sp_filters') && std.isArray(det.sp_filters)
               : det.name + ".sp_filters must be an array";
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
