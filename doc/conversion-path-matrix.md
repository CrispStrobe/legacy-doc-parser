# Independent conversion paths and lossy text projections

The native corpus already compares original OOXML, its binary DOC export,
native DOCX reimport and parser DOCX, including repeated binary cycles. More
passes through that same native implementation cannot establish independent
correctness. `tool/fidelity/path_matrix.py` adds attributed competing paths and
an independently implemented DOCX reader. It is a discovery tool; an observed
difference requires source attribution before becoming a parser regression.

## Paths recorded for each input

| Path | Question it helps investigate |
| --- | --- |
| Original DOCX → LibreOffice DOCX | What changes on an OOXML-only native resave? |
| Original DOCX → LibreOffice DOC | What crosses the older binary format boundary? The original remains retained. |
| Same DOC → LibreOffice DOCX and parser DOCX | Where do two import interpretations disagree on identical binary bytes? |
| Parser DOCX → LibreOffice DOC → each importer | What changes after our output is exported back to binary? |
| Native DOCX → LibreOffice DOC → each importer | What changes on the native control cycle? |
| Every DOCX → Pandoc AST → Markdown → Pandoc AST | Which differences survive a text-oriented projection, and which changes does that projection itself introduce? |
| Original and regenerated DOC → Antiword text | Does a separate binary DOC reader observe textual differences? |

The Pandoc paths run with explicit `accept`, `reject` and `all` revision views.
Both original AST and Markdown bytes are retained. The comparison normalizes
only an unambiguously resolved embedded image target to its actual byte hash;
it does not silently discard formatting nodes, field-related content, notes,
text or link targets. Metadata is measured separately from the body AST, both
between DOCX paths and before/after the Markdown projection. Reports version 2
retain `markdownMetadata`, `markdownMetadataRoundtrip` and an explicit body-only
scope for `markdownRoundtrip`. A real title/author control produces equal body
ASTs while ordinary non-standalone Markdown drops both metadata fields. This is
a loss in that selected Pandoc projection, not evidence of a DOC parser defect.
Version 1 reports did not include this second metadata comparison; their retained
`ast.json` and `markdown-ast.json` allow a separately attributed replay.

The original authored DOCX remains a reference after every cycle. Equality
between later generations does not erase loss introduced in the first one.
For original binary DOC inputs, the native DOCX is explicitly a competing
interpretation; it is not relabeled as an original Word-authored golden.

## Independent dimensions

The runner retains three complementary DOCX observations:

1. The namespace-aware XML oracle, including typed inline content and joins.
2. A small package inventory of note kinds, stories, field chunks, glyph/control
   elements and external relationships.
3. Pandoc's body AST, Markdown output and the AST obtained by reading that Markdown.

Each has a stated scope. A Pandoc `Note` does not distinguish footnotes from
endnotes. Equal ASTs can therefore hide that change; the separate package
observation must remain visible. Headers, footer assignments, field behavior,
bookmarks, revisions, editable structure and layout cannot be certified from
equal Markdown. Raw counts alone cannot prove correct anchor-to-content joins.
The [typed inline oracle](independent-semantic-oracles.md) supplies independent
counterexamples for those joins and for equal cached field results.

LibreOffice's reader, writer and OOXML resave paths belong to one implementation
family. Pandoc's readers and writers likewise belong to one family. Antiword is
a separate DOC text implementation with its own omissions and failure cases.
Repeated agreement within one family is not an additional independent vote.
Every tool version, executable hash, command, timeout, stderr and exit status is
retained. No converter is called an infallible oracle.

## Format and failure controls

Document content determines format. RTF bytes named `.doc` fail a binary-DOC
edge; this matters for converters whose advertised `.doc` export is an RTF
compatibility path. A CFB signature identifies the binary container only;
the DOC importer must still validate Word streams, FIB and supported version.
DOCX validation requires the actual Word main part and its document content
type, bounded ZIP expansion and safe unique member names. Schema validity is
a separate gate, not implied by the file signature.

Missing/failed dependencies remain blocked, never equal. A reader error makes
that projection unavailable and is retained as an execution error, without
automatically blaming the parser. Commands use argument arrays and isolated
native profiles with macros and link/field updates disabled. The runner does
not follow document hyperlinks or fetch external images. Timeouts terminate
the command process group and keep completed output and diagnostics.

Reports are checkpointed at command and node boundaries. Each original and
intermediate is hashed before and after use; source inputs and compiler inputs
must remain unchanged. Reports identify the Git commit/tree and dirty state.
Supplying an existing parser executable explicitly records that its build
provenance needs the caller's separate receipt; compiling with `--dart` binds
the executable to this run's recorded repository inputs.

## Running a small matrix

Resolve the package with a retained dependency lock and package configuration
first. Use installed tools; the runner downloads or installs nothing:

```sh
python3 -m unittest discover -s tool/fidelity -p test_path_matrix.py
python3 tool/fidelity/path_matrix.py \
  --office /path/to/soffice --pandoc /path/to/pandoc --dart /path/to/dart \
  --antiword /path/to/antiword --antiword-data /path/to/antiword/Resources \
  --input test/fixtures/fidelity/word.docx \
  --input test/fixtures/fidelity/note-markers.docx \
  --input test/fixtures/fidelity/semantic-contracts/locked-fields.docx \
  --output /path/to/new-matrix-output
```

The output directory must be new. Do not put it inside the measured fidelity
tool source directory. The normal exit code reports execution completion;
`completed-discovery` does not assert fidelity. Inspect `errors`, blocked or
unavailable projections, every attributed comparison and the original source
contracts. The raw `case.json` and `report.json` preserve their observations;
this tool never updates a golden or turns a difference into an expected pass.

The twelve focused controls cover format mislabeling, unsafe/duplicate ZIP members,
missing values and JSON types, image byte identity, footnote/endnote projection
loss, Markdown metadata loss with equal body content, namespace aliases,
unavailable comparisons and failed/timed-out commands.
They test the harness, not actual native conversion; real measurements require
the installed tools and separately retained execution receipts.
