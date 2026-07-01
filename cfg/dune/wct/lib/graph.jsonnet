// cfg/dune/wct/lib/graph.jsonnet
//
// Composition conventions for DUNE WCT sub-graphs, built on WCT's own pgraph
// pnode library (share/wirecell/pgraph.jsonnet).  This is the single import a
// detector/job builder needs for graph construction.
//
// WHY pnodes (settled in beads ddm-4pz):
//   A "pnode" wraps a WCT inode (a {type,name,data} component) together with
//   its declared input/output ports plus the other components it `uses`.
//   Building sub-graphs as port-bearing pnodes lets us COMPOSE them
//   (pg.pipeline / pg.fan.*) instead of hand-writing Pgrapher edge lists, and
//   it makes service sharing fall out for free (see "Service sharing" below).
//
// Conventions:
//
//   * A builder returns a pnode.  Use source()/filter()/sink()/node() to wrap
//     an inode with the right port arity.
//   * Compose with pipeline() (linear) or fan.* (fan-out/in across anodes).
//   * Finalize a CLOSED graph (no dangling ports) with application(), which
//     returns the [ ...components..., Pgrapher ] sequence that the
//     wire-cell-phlex executor expects.
//
// Service sharing:
//
//   pg.uses() de-duplicates the final component list by value.  So if several
//   sub-graphs reference the SAME service inode object (DFT, Random, AnodePlane,
//   FieldResponse, ...) via their `uses`, that component appears exactly ONCE in
//   the output.  Build a service inode once and pass it into each builder; do
//   NOT rebuild an identically-named-but-distinct object per stage.

local pg = import "pgraph.jsonnet";
local wc = import "wirecell.jsonnet";

{
    // Re-exports so a consumer needs only this one import.
    pg:: pg,
    wc:: wc,

    // -----------------------------------------------------------------------
    // Port-bearing pnode constructors (our names over pg.pnode).
    //   `uses` lists the SERVICE components this node depends on but which are
    //   not themselves graph nodes (e.g. an AnodePlane referenced by a Drifter).
    //   Usually the inode itself already carries `.uses` (see job/parts.jsonnet),
    //   so this argument can be left empty; pg.uses() collects + orders both.
    // -----------------------------------------------------------------------

    // A source: no input, one output.
    source(inode, uses=[]):: pg.pnode(inode, nin=0, nout=1, uses=uses),

    // A sink: one input, no output.
    sink(inode, uses=[]):: pg.pnode(inode, nin=1, nout=0, uses=uses),

    // A 1->1 filter/transform.
    filter(inode, uses=[]):: pg.pnode(inode, nin=1, nout=1, uses=uses),

    // Arbitrary port arity.
    node(inode, nin, nout, uses=[]):: pg.pnode(inode, nin=nin, nout=nout, uses=uses),

    // -----------------------------------------------------------------------
    // Composition (re-exported for discoverability; identical to pg.*).
    // -----------------------------------------------------------------------
    pipeline(elements, name=""):: pg.pipeline(elements, name=name),
    intern:: pg.intern,
    fan:: pg.fan,

    // -----------------------------------------------------------------------
    // Finalize a closed pnode graph into the WCT config sequence consumed by
    // the wire-cell-phlex executor: every component (wired nodes AND the
    // services they reach via `.uses`) followed by a Pgrapher whose edges are
    // the graph's edges.
    //
    //   graph : a CLOSED pnode (built via pipeline/fan/intern)
    //   name  : Pgrapher instance name (the executor injects app_name as a TLA)
    //   type  : graph-executor type ("Pgrapher" or "TbbFlow")
    //
    // pg.uses() walks every node's `.uses` and TOPOLOGICALLY SORTS the result,
    // so a service is always emitted -- and configured -- before any client
    // that uses it (WCT configures in array order; OmnibusSigProc walks its
    // AnodePlane at configure() time, so the anode must come first; see
    // [[wct-config-order-sigproc]]).  As long as each inode declares its `.uses`
    // (see job/parts.jsonnet), no manual service list is needed.
    // -----------------------------------------------------------------------
    application(graph, name="wcphlex_pgrapher", type="Pgrapher")::
        pg.uses(graph) + [{
            type: type,
            name: name,
            data: { edges: pg.edges(graph) },
        }],
}
