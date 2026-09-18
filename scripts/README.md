# dune-config scripts

Named commands for "popular" DUNE workflows.

The goal of this directory is to give a **name** to an emerging set of common
workflows so they can be referred to, discovered, and run without re-deriving a
command line each time.  A script here may be:

- a thin wrapper that runs **Phlex** on a *baked-in* Jsonnet configuration,
  adjusted only by command-line options (the common case), or
- a fuller shell script or a Snakemake workflow, when the job spans several
  steps.

## Conventions

- **Detector as an option.**  When a job ultimately depends on a specific
  detector, that is a command-line option (`-d/--detector`), and the script
  guesses it from the input when it reasonably can (e.g. from a DUNE DAQ file
  name).  New naming conventions are added as they arise.
- **Baked config + TLAs.**  Wrapper configs live under `cfg/` and are written as
  Jsonnet `function(...)`s whose top-level args the script fills.  Because
  `phlex` [cannot yet compile its own Jsonnet](https://github.com/orgs/Framework-R-D/discussions/522),
  scripts drive **`phlexed`**, which honors the usual Jsonnet flags — TLAs
  (`-A/--tla-str`, `--tla-code`) and search paths (`-J/--jpath`, `PHLEXED_PATH`,
  the analog of WCT's `WIRECELL_PATH`).
- **Activated environment.**  Scripts assume an activated build environment:
  `phlexed` on `PATH`, the Phlex plugins loadable, and the WCT config tree on
  `WIRECELL_PATH`.  A script derives what it can (e.g. channel-map and WCT-cfg
  locations) from `phlexed`'s install prefix.
- **`--dry-run`.**  Where practical, a script accepts `-n/--dry-run` to print the
  resolved underlying command instead of running it.

## Available scripts

| script | workflow |
|---|---|
| [`daq-to-frame-file`](daq-to-frame-file) | Read a DUNE DAQ HDF5 file and write a WCT frame file (`.npz`/`.tar`/`.tar.gz`/`.zip`) via Phlex + the `dune-daq-phlex` source and WCT's `FrameFileSink`. |

### `daq-to-frame-file`

```
daq-to-frame-file [options] <in.hdf5>
```

Reads a DUNE DAQ HDF5 file and writes a WCT frame file.  Output defaults to the
input base name with the extension replaced by `.npz` (any WCT container format
is allowed via the `-o/--output` extension).  The detector is guessed from the
file name (`np04hd*`→`pdhd`, `np02vd*`→`pdvd`) unless given with `-d/--detector`;
it selects a pinned default channel map (override with `--channel-map`).  See
`daq-to-frame-file --help` and the config `cfg/daq-to-frame-file.jsonnet`.

Depends on the `dune-daq-phlex` package (the Phlex DUNE-DAQ-HDF5 read source +
driver) and `wire-cell-phlex` (the `wcph_frame_sink` node + `frame-file-sink
.jsonnet`).
