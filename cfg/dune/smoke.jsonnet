// cfg/dune/smoke.jsonnet
//
// Trivial placeholder config used by the package smoke test (and as the first
// proof that the "dune/" import namespace resolves on the jsonnet/WIRECELL
// search path).  Real configuration is added by later beads tasks under
// dune/wct/ and dune/phlex/.  This file may be removed once real content can
// serve the same smoke-test role.
{
    package: "dune-config",
    ok: true,
    note: "dune/ namespace resolved on the jsonnet search path",
}
