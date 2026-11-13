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
// Input/output ends also take the boundary inode {type, name} that the
// wire-cell-phlex shape executor injects as an element of its "sources" /
// "sinks" TLA arrays; the defaults (boundary.*) are used only when a job is
// compiled outside an executor (tests, goldens).

local g = import "graph.jsonnet";

// A boundary inode as the executor injects it ({type, name}), made a full
// component (boundary nodes take no configuration).
local bnode(inode) = { type: inode.type, name: inode.name, data: {} };

{
    // Default boundary inodes, matching what the executor would inject.
    boundary:: {
        deposet_source: { type: "DepoSetBoundarySource", name: "wcphlex_deposet_source" },
        frame_source:   { type: "FrameBoundarySource",   name: "wcphlex_frame_source" },
        frame_sink:     { type: "FrameBoundarySink",     name: "wcphlex_frame_sink" },
        deposet_sink:   { type: "DepoSetBoundarySink",   name: "wcphlex_deposet_sink" },
    },

    // -----------------------------------------------------------------------
    // Processing bodies (port-bearing sub-graphs).
    // -----------------------------------------------------------------------
    bodies:: {
        // deposet -> frame: drift + electronics simulation + digitization.
        // drifted=true: the depos are already drifted (by a detector-wide
        // drift, see drift below); select this anode's instead of drifting.
        sim(P, drifted=false):: {
            pnodes: [
                g.filter(if drifted then P.depofilter else P.setdrifter),
                g.filter(P.transform),
                g.filter(P.reframer),
                g.filter(P.addnoise),
                g.filter(P.digitizer),
            ],
        },

        // deposet -> deposet: drift over the whole detector (job/drift.jsonnet)
        drift(P):: {
            pnodes: [g.filter(P.setdrifter_detector)],
        },

        // Hydra: wrap a deposet -> frame body so that an empty depo set
        // skips it and yields an empty frame (DeposOrBust + FrameSync).
        // body : { pnodes } whose first takes depos and last gives a frame.
        hydra(P, body):: {
            local work = g.pipeline(body.pnodes, "hydra_work_" + P.a.name),
            local dorb = g.node(P.deposorbust, 1, 2),
            local sync = g.node(P.framesync, 2, 1),
            pnodes: [g.intern(
                innodes=[dorb], outnodes=[sync], centernodes=[work],
                edges=[
                    g.pg.edge(dorb, work, 0, 0),
                    g.pg.edge(work, sync, 0, 0),
                    g.pg.edge(dorb, sync, 1, 1),
                ],
                name="hydra_" + P.a.name)],
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
        "deposet-file":: function(P, src=$.boundary.deposet_source) {
            pnodes: [g.source(bnode(src))],
        },

        // frames in (e.g. NPZ frame file)
        "frame-file":: function(P, src=$.boundary.frame_source) {
            pnodes: [g.source(bnode(src))],
        },

        // raw DUNE-DAQ HDF5 in -> frame.  STUB: at the WCT level this is just a
        // frame boundary; the decode (dune-daq-codec) + file-driven drive live in
        // a future phlex DAQ source, gated on Phlex 0.3.0 (ddm-3j8.1.6, ddm-4pz.10).
        "daq-hdf":: function(P, src=$.boundary.frame_source) {
            pnodes: [g.source(bnode(src))],
        },

        // simulation: deposets in, drift+sim+digitize -> frame (composite end).
        "sim":: function(P, src=$.boundary.deposet_source)
            {
                pnodes: $.inputs["deposet-file"](P, src).pnodes + $.bodies.sim(P).pnodes,
            },
    },

    // -----------------------------------------------------------------------
    // Output ends (boundary sinks), keyed by job-level output kind.
    // -----------------------------------------------------------------------
    outputs:: {
        "frame-file":: function(P, snk=$.boundary.frame_sink) {
            pnodes: [g.sink(bnode(snk))],
        },
        "deposet-file":: function(P, snk=$.boundary.deposet_sink) {
            pnodes: [g.sink(bnode(snk))],
        },
    },

    // Input kinds whose output is an IFrame (i.e. can feed the sigproc body) --
    // the set the SP-input swap (ddm-4pz.10) chooses among.
    frame_inputs:: ["sim", "frame-file", "daq-hdf"],
}
