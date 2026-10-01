// Baked Phlex workflow for the `daq-to-frame-file` script: read a DUNE DAQ HDF5
// file and write a WCT frame file (npz/tar/tar.gz/zip) via WCT's FrameFileSink.
//
// This is a TLA-parameterized version of dune-daq-phlex/test/daq-to-frame-file
// .jsonnet; the wrapper script fills the top-level args.  Compile/run it with
// `phlexed` (which honors these TLAs; plain `phlex` cannot yet):
//
//   phlexed -c daq-to-frame-file.jsonnet \
//     -A in_file=<in.hdf5> -A channel_map=<ChannelMap.txt> -A out_file=<out.npz>
//
// Graph (see the dune-daq-phlex README for the source/driver "collusion"):
//   dune_daq_phlex_driver -> dune_daq_phlex_source (DAQ HDF5 -> Arrow wc.frame)
//     -> wire_cell_phlex_arrow_from_arrow (-> WCT frame)
//       -> wcph_frame_sink (WCT FrameFileSink -> out_file)
//
// The sink's WCT sub-graph `frame-file-sink.jsonnet` comes from wire-cell-phlex
// and is resolved by WCT's own loader on WIRECELL_PATH at run time (not by
// phlexed) -- the wrapper ensures it is on the path.  FrameFileSink picks the
// container format (.npz/.tar/.tar.gz/.zip) from the out_file extension.

function(
    in_file,                 // DUNE DAQ HDF5 (string)
    channel_map,             // DUNE ChannelMap*.txt for the detector (string)
    out_file,                // WCT frame file, extension selects the format (string)
    tick = 0.5e-6,           // sample period (s); detector config, not in the payload
    first_record = 0,        // 0-based index of the first trigger record to process
    max_records = 0,         // max records from first_record; 0 = all remaining
)
{
    stage: 'daq-to-frame',  // the job's stage name (required since Phlex 0.4)
    driver: {
        cpp: 'dune_daq_phlex_driver',
        uses_sources: ['daq'],   // drive the trigger records this source found
        layers: ['event'],       // layer shape only; the source supplies the cells
    },
    sources: {
        daq: {
            cpp: 'dune_daq_phlex_source',
            input_file: in_file,
            channel_map: channel_map,
            tick: tick,
            product: 'frame',
            output_creator: 'input',
            output_layer: 'event',
            first_record: first_record,
            max_records: max_records,
        },
    },
    modules: {
        from_arrow: {
            cpp: 'wire_cell_phlex_arrow_from_arrow',
            input_creator: 'input',   // matches the source's output_creator
            input_layer: 'event',
            types: ['frame'],
        },
        frame_sink: {
            cpp: 'wcph_frame_sink',
            wct_config: 'frame-file-sink.jsonnet',          // wire-cell-phlex (WIRECELL_PATH)
            wct_plugins: ['WireCellPgraph', 'WireCellSio'],
            // In Phlex 0.3.2 a transform's output creator is its own module
            // label (the instance name) and its layer is the input's layer, so
            // from_arrow emits its frame as (from_arrow, event, frame).
            inputs: [{ creator: 'from_arrow', layer: 'event', suffix: 'frame' }],
            outputs: [],
            wct_tla: { outname: out_file },
        },
    },
}
