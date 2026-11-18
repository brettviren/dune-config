# `dune/wct/detectors/` — detector descriptions

One subdir per canonical detector, each a `function(params) ->
detector-description` built on `dune/wct/lib/schema.jsonnet`.  Variants (ideal
vs as-built, gain settings, geometry phases) are overlays selected by
`params.variant`, not separate detectors.  The `../detectors.jsonnet` registry
maps canonical `detname -> function`.

| detname | Detector | Anodes | Variants | Source |
|---|---|---|---|---|
| `pdhd` | ProtoDUNE-HD | 4 APAs | `ideal`, `real` (APA0 as-built FR) | dunereco `pdhd/` |
| `pdsp` | ProtoDUNE-SP | 6 APAs | `ideal` | dunereco `pdsp/` |
| `pdvd` | ProtoDUNE-VD | 8 (0-3 bottom, 4-7 top) | `ideal` | dunereco `protodunevd/` |
| `fdvd` | DUNE FD-VD (v6, 2x8x40) | 320 CRUs (0-159 bottom, 160-319 top) | `ideal` (BDE 14 mV/fC), `bde7d8` (7.8 mV/fC) | dunereco `dune10kt-vd/` |
| `fdhd` | DUNE FD-HD (dune10kt v6) | 150 APAs (`ideal`), 12 (`1x2x6`), 4 (`1x2x2`) | geometry only: `ideal` (full), `1x2x6`, `1x2x2` | dunereco `dune10kt-1x2x6/`, `dune10kt-hd/` |

## What is per anode

Everything that can differ between anodes lives in `anodes[]`: faces, `elec`
(polymorphic by `type`: `ColdElecResponse` or `JsonElecResponse`, see
`schema.elec_fields`), `field` (file and its `response_plane`),
`filter_response`, `noise`, `adc` and `sigproc`.  Vertical-drift detectors use
this for their bottom (cold electronics) and top (top drift electronics)
volumes.  Detector-wide are `daq`, `lar`, `sim`, `wires`, `sp_filters`,
`sys_resp`, `rc_resp` and the non-timing `splat` settings.

Timing that follows from the response plane (ductor window, reframer `tbin`,
PIR padding, the splat window) is derived per anode in `job/parts.jsonnet`;
detectors do not repeat it.

