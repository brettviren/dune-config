# dune-config — pure-Jsonnet DUNE configuration package.
#
# This package ships no compiled code: it installs a tree of Jsonnet
# configuration that is consumed at runtime via the phlex/WIRECELL search
# path.  It is built as a CMake project only so the devel/ superbuild
# (devel/CMakeLists.txt) auto-discovers it (by project() name) and so a
# future Spack recipe (beads ddm-4pz.17) can install it the same way the
# other suite packages do.
#
# LANGUAGES NONE: no compiler is needed.  The devel/ superbuild forwards
# CMAKE_CXX_* cache vars to every sub-build; they are harmlessly ignored.
cmake_minimum_required(VERSION 3.21)
project(dune_config VERSION 0.1.0 LANGUAGES NONE)

include(GNUInstallDirs)

# ---------------------------------------------------------------------------
# Install the Jsonnet tree.
#
# The search root is <prefix>/share/dune-config/cfg.  Configs live beneath a
# top-level "dune/" namespace dir, so consumers import e.g.
#   import "dune/wct/detectors.jsonnet"
# after adding <prefix>/share/dune-config/cfg to WIRECELL_PATH (and the phlex
# jsonnet search path).  The "dune/" namespace keeps these from colliding with
# other packages that share the same WIRECELL_PATH.
# ---------------------------------------------------------------------------
install(DIRECTORY cfg/
  DESTINATION "${CMAKE_INSTALL_DATADIR}/dune-config/cfg"
  FILES_MATCHING PATTERN "*.jsonnet"
)

# ---------------------------------------------------------------------------
# Smoke test: prove the namespaced import resolves through the cfg search root.
#
# test/smoke-workflow.jsonnet does  import "dune/smoke.jsonnet"  and is
# evaluated with the cfg dir on the jsonnet library path (-J), mirroring how
# WIRECELL_PATH will expose it at runtime.
# ---------------------------------------------------------------------------
enable_testing()

find_program(JSONNET_EXECUTABLE
  NAMES jsonnet
  HINTS ${CMAKE_PREFIX_PATH} ENV PATH
  PATH_SUFFIXES bin
)

if(JSONNET_EXECUTABLE)
  message(STATUS "dune-config: jsonnet tests enabled (${JSONNET_EXECUTABLE})")

  # Tests that import only the package cfg tree (no wirecell.jsonnet) run with
  # just the cfg dir on the jsonnet library path.
  add_test(NAME dune_config_jsonnet_smoke
    COMMAND "${JSONNET_EXECUTABLE}"
      -J "${CMAKE_CURRENT_SOURCE_DIR}/cfg"
      "${CMAKE_CURRENT_SOURCE_DIR}/test/smoke-workflow.jsonnet"
  )

  # Detector schema + variant overlays (ddm-4pz.3): self-contained.
  add_test(NAME dune_config_schema_variant
    COMMAND "${JSONNET_EXECUTABLE}"
      -J "${CMAKE_CURRENT_SOURCE_DIR}/cfg"
      "${CMAKE_CURRENT_SOURCE_DIR}/test/schema-variant-test.jsonnet"
  )

  # The graph-composition test (ddm-4pz.2) imports graph.jsonnet, which pulls in
  # WCT's pgraph.jsonnet + wirecell.jsonnet from <prefix>/share/wirecell.  Locate
  # that dir on CMAKE_PREFIX_PATH (the Spack view, in the devel/ superbuild).
  set(_wct_share "")
  foreach(_prefix IN LISTS CMAKE_PREFIX_PATH)
    if(EXISTS "${_prefix}/share/wirecell/pgraph.jsonnet")
      set(_wct_share "${_prefix}/share/wirecell")
      break()
    endif()
  endforeach()

  if(_wct_share)
    add_test(NAME dune_config_graph
      COMMAND "${JSONNET_EXECUTABLE}"
        -J "${CMAKE_CURRENT_SOURCE_DIR}/cfg"
        -J "${_wct_share}"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/graph-test.jsonnet"
    )

    # Detector ports also import wirecell.jsonnet (units/helpers).
    add_test(NAME dune_config_pdhd
      COMMAND "${JSONNET_EXECUTABLE}"
        -J "${CMAKE_CURRENT_SOURCE_DIR}/cfg"
        -J "${_wct_share}"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/pdhd-test.jsonnet"
    )

    add_test(NAME dune_config_pdvd
      COMMAND "${JSONNET_EXECUTABLE}"
        -J "${CMAKE_CURRENT_SOURCE_DIR}/cfg"
        -J "${_wct_share}"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/pdvd-test.jsonnet"
    )

    # WCT job builders: composition + service-sharing (ddm-4pz.6).
    add_test(NAME dune_config_job
      COMMAND "${JSONNET_EXECUTABLE}"
        -J "${CMAKE_CURRENT_SOURCE_DIR}/cfg"
        -J "${_wct_share}"
        "${CMAKE_CURRENT_SOURCE_DIR}/test/job-test.jsonnet"
    )

    message(STATUS "dune-config: graph + detector + job tests enabled (wirecell share: ${_wct_share})")

    # WCT-config parity regression (ddm-4pz.11): compare each job sub-graph to a
    # committed golden snapshot, component-by-component (exact), via the
    # bundled compare_wct_configs.py.  Self-contained: no dependency on
    # wire-cell-phlex or reference/.  Refresh goldens after intentional changes
    # (see test/check-golden.sh / test/README.md).  Cross-checks against
    # wire-cell-phlex + dunereco live in test/compare-references.sh (on demand).
    find_program(PYTHON3_EXECUTABLE NAMES python3 python)
    if(PYTHON3_EXECUTABLE)
      set(_golden_matrix
        "sim|pdhd|0"  "sigproc|pdhd|0"  "sim-sigproc|pdhd|0"  "splat|pdhd|0"
        "sim|pdvd|0"  "sigproc|pdvd|0"  "sim-sigproc|pdvd|0"  "splat|pdvd|0"
        "sim|pdvd|4"  "sigproc|pdvd|4"
      )
      foreach(_spec IN LISTS _golden_matrix)
        string(REPLACE "|" ";" _parts "${_spec}")
        list(GET _parts 0 _job)
        list(GET _parts 1 _det)
        list(GET _parts 2 _ai)
        add_test(NAME dune_config_parity_${_det}_${_job}_a${_ai}
          COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/test/check-golden.sh"
            "${JSONNET_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/cfg"
            "${_wct_share}"
            "${CMAKE_CURRENT_SOURCE_DIR}/test/compare_wct_configs.py"
            "${CMAKE_CURRENT_SOURCE_DIR}/test/golden/${_det}-${_job}-a${_ai}.json"
            "${_job}" "${_det}" "${_ai}"
        )
      endforeach()
      message(STATUS "dune-config: WCT-config parity (golden) tests enabled")
    else()
      message(WARNING "dune-config: python3 not found; parity (golden) tests disabled")
    endif()
  else()
    message(WARNING "dune-config: wirecell.jsonnet not found on CMAKE_PREFIX_PATH; "
                    "graph composition test disabled")
  endif()
else()
  message(WARNING "dune-config: jsonnet not found; tests disabled")
endif()
