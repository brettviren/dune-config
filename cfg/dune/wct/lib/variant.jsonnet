// cfg/dune/wct/lib/variant.jsonnet
//
// Detector-variant mechanism (settled in beads ddm-4pz): one canonical detname
// with a `variant` param selecting an overlay merged onto the base detector
// (base + patch).  This file provides the merge primitives; each detector file
// under dune/wct/detectors/ defines its own variants explicitly and picks one
// with select(params).
//
// Two merge tools, because a detector has both scalar/object fields AND the
// `anodes` array:
//
//   apply(base, overlay)      -- DEEP-merge object fields (recurses into nested
//                                objects; preserves un-touched siblings).  Use
//                                for detector-level patches (lar, daq, sim, ...).
//
//   patch_anodes(det, patches)-- patch individual anodes by index.  `patches`
//                                is keyed by stringified anode index; each value
//                                is deep-merged into that anode only.  Use for
//                                as-built variants that affect specific anodes.
//
// Jsonnet's own `+` is a SHALLOW merge (a nested object in the overlay REPLACES
// the base's, and arrays are always replaced), which is why these helpers exist.
//
// Typical detector usage:
//
//   local variant = import "../../lib/variant.jsonnet";
//   function(params={detname:"pdhd"})
//     local base = schema.make({ ... });
//     local v = variant.select(params);                 // "ideal" | "real" | ...
//     local built = {
//       ideal: base,
//       real:  variant.patch_anodes(base, {"2": { elec: { gain: 7.8 } }}),
//     }[v];
//     // optional caller param overrides (lar/daq/...) on top:
//     variant.apply(built, { lar: std.get(params, "lar", {}) })

{
    // Pick the variant name from params (default "ideal" = base, no overlay).
    select(params, default="ideal")::
        if std.isObject(params) && std.objectHas(params, 'variant')
           && params.variant != null
        then params.variant
        else default,

    // Recursive deep merge: b wins on leaves; nested objects merge; non-objects
    // (incl. arrays) in b replace a.
    mergeDeep(a, b)::
        if std.isObject(a) && std.isObject(b)
        then {
            [k]:
                if std.objectHas(a, k) && std.objectHas(b, k)
                then $.mergeDeep(a[k], b[k])
                else if std.objectHas(b, k) then b[k]
                else a[k]
            for k in std.setUnion(std.objectFields(a), std.objectFields(b))
        }
        else b,

    // Detector-level deep merge (alias with intent-revealing name).
    apply(base, overlay):: $.mergeDeep(base, overlay),

    // Patch specific anodes by stringified index; others pass through unchanged.
    patch_anodes(det, patches):: det {
        anodes: [
            if std.objectHas(patches, std.toString(i))
            then $.mergeDeep(det.anodes[i], patches[std.toString(i)])
            else det.anodes[i]
            for i in std.range(0, std.length(det.anodes) - 1)
        ],
    },
}
