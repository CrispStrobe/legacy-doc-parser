# legacy_doc_parser

A portable Dart library for reading Word 97–2003 binary `.doc` and `.dot` files,
producing a structured document model and safe previews, and converting a
separate copy to DOCX or explicitly requested DOCM. The package runs on the Dart
VM and in JavaScript builds without Flutter, installed Office or a network
service.

The codebase currently supports:

- Main text, sections, headers, footers, footnotes, endnotes, comments and
  bookmarks, with original UTF-16 character positions retained in the model.
- Supported character and paragraph styles, independent script font slots,
  tabs, borders, shading, numbering,
  list continuation, section/gutter direction and explicit manual-break
  justification compatibility settings.
- Nested tables, supported cell merges and conditional table styles, row
  properties, and modeled floating-table anchors. Source note endings are
  preserved without adding layout-changing paragraphs after final tables.
- Supported tracked insertions/deletions and formatting histories. Field
  instructions and stored results are preserved, including bounded internal
  hyperlink fields; fields are not evaluated.
- Supported raster images, bounded EMF/WMF preservation and vector previews,
  basic editable OfficeArt shapes and paths, explicit drawing wrap clearances,
  and corroborated textbox chains and independent header/footer instances.
  Explicit simple textbox borders retain their source anchors while bounded
  DOCX frame conversion accounts for their outer border extent; see the
  [frame contract](doc/textbox-frame-borders.md). Qualified textbox paint includes
  source-valued opacity, dashes, simple shadows, scaled gradients and embedded
  picture/texture/monochrome-pattern fills.
- Bounded nonempty ISF stroke inspection with original packet coordinates,
  source transforms, pressure ranges and pen attributes, independently checked
  against actual Windows WPF. Raw ink remains retained; Word-native ink
  placement, rendering and editing are not inferred from decoded packets. See
  [supported ink inspection and limits](doc/ink-decoding.md).
- Structured DOCX conversion, safe HTML and plain-text extraction, and explicit
  DOCM output that can retain one structurally complete VBA project. Embedded
  objects, macros and signature evidence are retained only within the documented
  conversion contracts; the library never executes them.
- Explicit warnings, conversion limitations and preservation counts, so callers
  can distinguish supported output, recovered structures and retained evidence.

The library is under active development. These areas remain incomplete or need
further qualification:

- Exact Word pagination and rendering across fonts, shaping engines, table and
  floating-object layouts, wrapping, and compatibility settings. Valid OOXML
  and matching extracted text do not establish identical native layout.
- Arbitrary drawing groups, presets, transforms, effects, GDI text/bitmap/clipping
  operations, and unmodeled metafile records. Unsupported preview operations do
  not silently disappear into a claimed complete rendering.
- Every revision, move, table-topology and cross-story combination; resolved
  comment state and editable ink; general field evaluation and broader style
  semantics. Unsupported or ambiguous cases remain diagnosed or rejected.
- Lossless preservation of every legacy binary feature through conversion.
  Conversion produces a new package, not a binary `.doc` round trip. A binary
  DOC writer and encrypted/password-protected DOC input are not supported.
- Signature validation or preservation of signature validity after conversion.
  `signatureValidityClaimed` is always false.

Remaining work prioritizes independently checked native layout, broader bounded
format coverage, revision and drawing semantics, and a stable published API.
The [fidelity status](doc/fidelity-status.md) gives the supported contracts and
open gaps; the [oracle guide](doc/fidelity-oracles.md) explains how schema,
semantic and native-rendering checks differ.
The [current continuation handoff](doc/continuation-20261113-followup.md) records the
saved parser/app integration, complete validation and next bounded work.
The [13 November parser audit](doc/parser-audit-20261113.md) records subsequent
input/conversion hardening, portable acceptance and remaining native field
rendering differences.
The [audit follow-up](doc/parser-audit-20261113-followup.md) adds story-boundary,
field-text and compound-allocation fixes, with 1,175 passing Dart tests and
263 schema-valid DOCX outputs. All 260 earlier corpus outputs remain byte-exact.
The [third audit pass](doc/parser-audit-20261113-third-pass.md) adds exclusive
compound-sector ownership, public-model and native-image validation, nested
result controls, and list-label fixes. It passes 1,300 Dart tests and independent
schema checks for 297 outputs; all 263 preceding DOCX outputs remain byte-exact.
At that third-pass checkpoint, literal binary list labels containing `%1`–`%9`
were explicitly unsupported; the fifth pass below supersedes that restriction.
The [fourth audit pass](doc/parser-audit-20261113-fourth-pass.md) preserves
literal/ancestor list labels and exact label TABs, validates text-only UTF-16
before display filtering, and checks actual OLE/VBA container bytes before
native activation. It passes 1,361 Dart tests and independent schema checks
for 320 packages; all 297 preceding DOCX outputs remain byte-exact.
The [fifth audit pass](doc/parser-audit-20261113-fifth-pass.md) adds bounded
compound metadata and shared directory ownership, note-reference ownership,
public formatting-domain checks, literal-percent list labels and sparse marker
inheritance. It also adds `LegacyWordFieldMode.cachedResults` for callers that
need stored field display without active field recalculation, with the field
tree and revision history retained as inert evidence. Its historical acceptance
receipts survived, but the interrupted evidence upload retained only 3,124 of
14,103 inventoried files. See the [recovery index](doc/evidence/parser-audit-20261113-fifth-pass/README.md)
for the exact retained and missing scope; native totals from the interrupted
session are not new acceptance results.

The [14 November audit continuation](doc/parser-audit-20261114.md) fixes section
geometry and range coverage, validates hidden comment references, and repairs
reusable compound byte-sink state. It brings all public-model export corpora
into CI's SDK gate. Clean runtime `2f8a307` passes 3,688 Dart tests, 195 Python
controls, 34 compiled-JavaScript groups and 1,426 schema validations.
[Compact evidence](doc/evidence/parser-audit-20261114/README.md) retains the exact
receipts and new section outputs; this pass makes no new native-rendering claim.

The [14 November follow-up](doc/parser-audit-20261114-followup.md) fixes six
further gaps: direct public cell shading, embedded-object Boolean operands,
fixed heading levels, indirect paragraph-property replacement, bookmark
validation and story boundaries, and textbox identities, ownership and chains.
Clean tested source `a25e4ea824886327b97bde2873e6ef175a5ab971` passes 3,903 Dart
tests, 197 Python controls, 38 compiled-JavaScript groups and 1,533 SDK package
validations (1,114 DOC-derived and 419 public-model outputs). All 24 retained
oracle inputs validate, 353 Dart files require no formatting changes, and the
publish dry run reports zero warnings. The
[follow-up evidence](doc/evidence/parser-audit-20261114-followup/README.md)
identifies that tested source separately from later documentation commits;
these checks add no new native-rendering claim.

Use Dart 3.8 or later. `archive` is the runtime package dependency. A development
Git dependency can be configured as follows; pin a reviewed full commit SHA
instead of `main` for reproducible consumer builds and retain the lockfile.

```yaml
dependencies:
  legacy_doc_parser:
    git:
      url: https://github.com/CrispStrobe/legacy-doc-parser
      ref: main
```

```dart
import 'dart:typed_data';
import 'package:legacy_doc_parser/legacy_doc_parser.dart';

void inspectAndConvert(Uint8List source) {
  final document = parseLegacyWordDocument(source);
  print(document.plainText);
  print(document.warnings);

  final copy = convertLegacyWordToStructuredDocx(source);
  print(copy.limitations);
  // Save copy.bytes to a new .docx file; the source bytes are never modified.
}
```

`convertLegacyWordDocument` accepts an already parsed document. For explicit
macro-capable output, use
`convertLegacyWord(source, format: LegacyWordOutputFormat.docm)` and inspect the
reported limitations. `extractLegacyWordText` and `convertLegacyWordToDocx` are
text-only APIs; they do not provide structured conversion fidelity.

The [CLI example](example/legacy_doc_parser_example.dart) prints a summary or
writes a separate output, refusing to overwrite an existing destination:

```sh
dart run example/legacy_doc_parser_example.dart input.doc
dart run example/legacy_doc_parser_example.dart input.doc new-copy.docx
dart run example/legacy_doc_parser_example.dart input.doc new-copy.docm
```

Run the portable acceptance checks with:

```sh
dart pub get
dart format --output=none --set-exit-if-changed lib test tool example
dart analyze
dart test
python3 tool/verify_web.py
python3 -m unittest discover -s tool/fidelity -p 'test_*.py'
```

CI also runs a source-built independent Open XML SDK validator with an exact
corpus and positive/negative controls. Native rendering needs an installed
Office application and its own retained evidence. Consumer pins are maintained
by [Quds](https://github.com/CrispStrobe/quds_office_suite) and
[CrispCloud](https://github.com/CrispStrobe/CrispCloud).

License: [Mozilla Public License 2.0](LICENSE). Third-party components and
fixtures retain their applicable MIT, 0BSD and other notices; see
[NOTICE](NOTICE) and [third_party](third_party/).
