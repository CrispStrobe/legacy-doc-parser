# Parser audit continuation — 14 November 2026

## Recovery baseline

This pass starts from `731e37032e11a3bc1ae6bdb0475fdcb48067bda4` on `main` and saves work incrementally on `fix/parser-audit-20261114`.

The interrupted session's runtime fixes survived on GitHub. The prior audit branch ends at `4de67fe946bd13304e5999759f1d9846e9a50864`; merge `83acdf1c8b6b1b6346f0744988ef3d15f9fa08ff` integrated it into main, followed by the macOS canonical fixture-path correction at `731e370`.

The baseline's [GitHub Actions run](https://github.com/CrispStrobe/legacy-doc-parser/actions/runs/43533420031) completed successfully. Historical local receipts and this hosted result are separate evidence.

## Interrupted evidence upload

The fifth-pass control archive names 17 data ZIPs. Only parts 001–004 and the control archive are present in the saved tree. A recovery check verified all 3,124 retained manifest files against their SHA-256 values; 10,979 of the declared 14,103 files are absent in parts 005–017. The saved test receipts are usable, but missing native-rendering files cannot be reconstructed from a transcript or represented as independently reverified results. A separate recovery report records the surviving scope.

## Current work

- Audit compound-file identities, ownership and bounds.
- Audit public document-model source ranges and semantic references before DOCX emission.
- Add focused regression cases for confirmed defects and validate changes through hosted CI.
- Correct stale documentation and retain compact, reproducible evidence as each batch completes.

## Validation environment

The fresh local workspace exhausted its storage while unpacking a temporary Dart SDK, before any production edits. Sandbox command startup then failed; elevated cleanup is disabled by the environment policy. This pass therefore uses the connected GitHub API for incremental commits with expected-head, non-force branch updates and the repository's existing Actions jobs for execution. No new local Dart, Python, JavaScript, schema or native results are claimed.

This file is a running checkpoint. Findings and measured outcomes are added as checks finish.
