# Native corpus continuation at 7308125

## Checkpoint in progress

This checkpoint retains **13 of 22 completed source cases** and
**39 completed repeat imports**.
Each retained case has its complete losslessly compressed native report,
verified input/output/PDF/text/geometry/raster archive and exact manifest.
`index.json` is the unchanged atomic progress snapshot from the running job;
its active case is not counted as completed evidence. Later commits will append
completed seals and record the final aggregate.

All measurements use clean parser commit
`730812534e8dc045d6d97f600218228f05c51b97`. Each source runs through a separate
normal `tool/fidelity/run.py --case ID --roundtrip-cycles 3 --raster-storage gzip`
invocation. This is a serial collection of independently receipted runs, with
compiler/source/renderer/font consistency checked across them. Every invocation
retains its own compiled-executable identity; it is not represented as one
uninterrupted invocation.

The wrapper seals and independently verifies each completed case before removing
only that case's generated raw directory. Original inputs, native DOC bridges,
converted DOCX, PDFs, text, bounding boxes, compressed RGB pages and stage records
are retained in the per-case archives. Generated Office profiles and the
compiled executable are excluded; the executable hash and full build/source
receipt remain in each report. Every compressed raster is bound to its exact
page, raw PPM hash, compressed hash and render/storage receipts.

Run `python3 verify_native_artifacts.py --directory sealed/01-formatting` from
this directory to verify a case; add `--extract NEW_DIRECTORY` to extract only
after verification. The standalone scripts are copied unchanged from this
execution, and their hashes are pinned by the index. The wrapper requires an
exact clean source checkpoint and refuses incomplete-output overwrites.

Equal page counts, exact rendering and structural equivalence are reported
separately. No difference is silently converted into a pass; no golden is
updated by these commands. Microsoft Word was not executed.
