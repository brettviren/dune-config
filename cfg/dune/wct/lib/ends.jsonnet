// cfg/dune/wct/lib/ends.jsonnet
//
// Swappable I/O "ends" + processing "bodies" for WCT job graphs (beads ddm-4pz.8).
//
// An END is the boundary node where a phlex source/sink meets the WCT graph; a
// BODY is a processing sub-graph.  Both are returned as { pnodes } -- an ORDERED
// list of stage pnodes (source..sink order).  Each stage pnode wraps an inode
// that declares its service dependencies via `.uses` (see job/parts.jsonnet), so
// pg.uses() pulls in and topologically orders every referenced service; there is
// no separate service list to thread through.
//
// A job is then just:
//   graph.pipeline(inputs[in_kind].pnodes + body.pnodes + outputs[out_kind].pnodes)
// and swapping the SP input between simulation / frame-file / raw-DAQ becomes a
// change of `in_kind` rather than a new job file (the ddm-4pz.10 milestone).
//
// WCT-level truth vs job-level kinds: at the WCT graph there are only two input
// boundary data types (deposet, frame).  The four job-level input kinds collapse
// onto them -- the file/sim/daq distinction is a PHLEX-source concern handled in
// ddm-4pz.9.  "sim" is a composite end (deposet boundary + drift/sim/digitize)
// that PRODUCES frames; "frame-file" and "daq-hdf" are bare frame boundaries.
//
// Each end/body takes the per-anode parts object P (see job/parts.jsonnet).

local g = import "graph.jsonnet";

{
    // -----------------------------------------------------------------------
    // Processing bodies (port-bearing sub-graphs).
    // -----------------------------------------------------------------------
    bodies:: {
        // deposet -> frame: drift + electronics simulation + digitization
        sim(P):: {
            pnodes: [
                g.filter(P.setdrifter),
                g.filter(P.transform),
                g.filter(P.reframer),
                g.filter(P.addnoise),
                g.filter(P.digitizer),
            ],
        },

        // frame -> frame: signal processing
        sigproc(P):: {
            pnodes: [g.filter(P.sigproc)],
        },

        // deposet -> frame: DepoFluxSplat ("true signal")
        splat(P):: {
            pnodes: [
                g.filter(P.setdrifter),
                g.filter(P.splat),
                g.filter(P.reframer),
            ],
        },
    },

    // -----------------------------------------------------------------------
    // Input ends (boundary sources), keyed by job-level input kind.
    // All but "deposet-file" present an IFrame at their output port.
    // -----------------------------------------------------------------------
    inputs:: {
        // deposets in (e.g. NPZ deposet file)
        "deposet-file":: function(P, name="wcphlex_deposet_source") {
            pnodes: [g.source({ type: "DepoSetBoundarySource", name: name, data: {} })],
        },

        // frames in (e.g. NPZ frame file)
        "frame-file":: function(P, name="wcphlex_frame_source") {
            pnodes: [g.source({ type: "FrameBoundarySource", name: name, data: {} })],
        },

        // raw DUNE-DAQ HDF5 in -> frame.  STUB: at the WCT level this is just a
        // frame boundary; the decode (dune-daq-codec) + file-driven drive live in
        // a future phlex DAQ source, gated on Phlex 0.3.0 (ddm-3j8.1.6, ddm-4pz.10).
        "daq-hdf":: function(P, name="wcphlex_frame_source") {
            pnodes: [g.source({ type: "FrameBoundarySource", name: name, data: {} })],
        },

        // simulation: deposets in, drift+sim+digitize -> frame (composite end).
        "sim":: function(P, name="wcphlex_deposet_source")
            {
                pnodes: $.inputs["deposet-file"](P, name).pnodes + $.bodies.sim(P).pnodes,
            },
    },

    // -----------------------------------------------------------------------
    // Output ends (boundary sinks), keyed by job-level output kind.
    // -----------------------------------------------------------------------
    outputs:: {
        "frame-file":: function(P, name="wcphlex_frame_sink") {
            pnodes: [g.sink({ type: "FrameBoundarySink", name: name, data: {} })],
        },
        "deposet-file":: function(P, name="wcphlex_deposet_sink") {
            pnodes: [g.sink({ type: "DepoSetBoundarySink", name: name, data: {} })],
        },
    },

    // Input kinds whose output is an IFrame (i.e. can feed the sigproc body) --
    // the set the SP-input swap (ddm-4pz.10) chooses among.
    frame_inputs:: ["sim", "frame-file", "daq-hdf"],
}
