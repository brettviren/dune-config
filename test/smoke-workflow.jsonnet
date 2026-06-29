// test/smoke-workflow.jsonnet
//
// Package smoke test.  Evaluated by ctest as:
//   jsonnet -J <pkg>/cfg test/smoke-workflow.jsonnet
//
// It imports through the "dune/" namespace exactly as runtime consumers will
// (once <prefix>/share/dune-config/cfg is on WIRECELL_PATH).  Success means the
// search root is wired correctly; the asserted value guards against a silently
// empty result.
local smoke = import "dune/smoke.jsonnet";

assert smoke.ok : "dune-config smoke import did not resolve as expected";

smoke { checked: true }
