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

    message(STATUS "dune-config: graph + detector tests enabled (wirecell share: ${_wct_share})")
  else()
    message(WARNING "dune-config: wirecell.jsonnet not found on CMAKE_PREFIX_PATH; "
                    "graph composition test disabled")
  endif()
else()
  message(WARNING "dune-config: jsonnet not found; tests disabled")
endif()
