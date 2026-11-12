# Tracked revisions and comment fidelity

The parser retains revisions; it does not accept or reject them. This is a
bounded reconstruction of the documented binary records, not a claim of full
Word revision fidelity.

## Formatting and text revisions

- `sprmCWall` / `sprmPWall` capture the resolved formatting immediately before
  the wall. Later properties remain the current formatting. A false wall clears
  the previous snapshot. Style changes and `CPlain` preserve the saved state.
- Character and paragraph `PropRMark` records retain the author-table index,
  raw DTTM, resolved author and wall-clock date. Current-formatting previews
  mark supported changes without displaying old hidden text.
- Native DOCX `w:rPrChange` and `w:pPrChange` contain the supported previous
  properties. Missing snapshots remain disclosed evidence; the writer does not
  fabricate an empty prior style and call it a recovered change.
- Insertions and deletions have separate provenance, even when both apply to
  the same range. Revision-save IDs are retained when supplied. The original
  `revisionAuthor` / `revisionTime` fields remain a compatibility view.
- A paragraph mark has its own formatting and insertion/deletion state.
  `w:pPr/w:rPr/w:ins` or `w:del` represents that state independently of the
  paragraph text. The HTML preview shows a marked paragraph symbol; plain text
  keeps its existing content and paragraph boundaries.

The binary timestamp has no time zone. DOCX dates omit a zone instead of
asserting UTC. Missing authors or invalid dates stay missing and produce the
revision-metadata limitation. Unsupported pre-wall properties also produce that
limitation, even when the supported subset can be exported.

## Section formatting revisions

`sprmSWall` captures the supported section properties before subsequent SPRMs
modify the current state. `sprmSPropRMark` supplies the author and source date;
`sprmSRsid` retains the section save identifier even without an active revision.
The public section model exposes the prior state separately, and DOCX writes
native `w:sectPrChange` with a complete prior set of the supported properties.
Page size, orientation, margins, equal/unequal columns, section numbering,
document grids and title-page state can therefore be rejected independently of
the current settings. Prior section properties are validated too: a valid
current value cannot hide a malformed historical snapshot. Missing or unmarked
snapshots stay explicit evidence rather than fabricated history.

A binary section's break type terminates that section, whereas OOXML places the
break type on the following section. The writer shifts both the current break
and its prior value. If the receiving section already has a separately authored
layout revision, one `sectPrChange` cannot express both independent authors.
The local layout revision remains native; the incoming break revision remains
disclosed evidence. A changed terminal binary break likewise has no following
OOXML section and is disclosed. These cases are not reported as full fidelity.
Header/footer references remain outside `sectPrChange`, as required by the
native previous-section schema. The parser does not invent revision history for
header/footer relationships that the section SPRMs do not encode.

## Paragraph numbering revisions

`sprmPNumRM` is decoded as its fixed 128-byte `NumRM` record. The public
paragraph model exposes the previous-numbered state, insertion flag, author,
source date, and a normalized native historical numbering string, with an
immutable copy of the source record. All nine previous level values, formats
and placeholder positions remain in that evidence. `sprmPFNumRMIns` works both
through ordinary paragraph properties and PRM0; paragraph-style changes retain
these review properties independently of the current list selection.

Native DOCX stores representable prior labels in `w:numPr/w:numberingChange`
and newly applied numbering as `w:numPr/w:ins`. These do not mark the paragraph
text inserted. Removing a list retains its previous numbering beside an
explicit `w:numId` reset. Native numbering history is a legacy value cache; it
does not reconstruct an unavailable old abstract-list definition or invent a
multi-step edit history. Current numbering keeps its independent list identity
and continuation rules.

Numbering history whose template has a literal prefix, an ambiguous percent
separator, invalid XML controls, or an unrepresentable number-format code is
retained with a specific revision limitation. Its native revision marker has
no fabricated `original` label. Missing author metadata stays incomplete.
Invalid record lengths, Boolean operands, text extents, Unicode and placeholder
indices are rejected before conversion. Non-applicable template data in a
record for a previously unnumbered paragraph is not interpreted.

## LISTNUM display-field revisions

`sprmCDispFldRMark` retains the previous literal result of a `LISTNUM` field,
its author and source timestamp, independently of revisions to surrounding text
or paragraph numbering. The fixed 39-byte source record remains immutable
evidence. The source flag follows its documented nonzero semantics; zero clears
the history. The parser validates text bounds and Unicode and rejects histories
attached to a different field type or contradictory histories on one field.

Representable history is native `w:fldChar/w:numberingChange` on the begin
character. The field remains locked with its current cached result. The parser
does not recalculate field instructions or accept the revision. Explicitly
hidden history and history inside private fields remain inert evidence, as do
previous results containing unsupported XML controls. An omitted native
`original` value never implies a reconstructed previous result.

The implementation follows [MS-DOC DispFldRmOperand](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/47381e7e-b79f-4069-9634-4f24fa8d8b2b)
and the field-specific [NumberingChange semantics](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.wordprocessing.numberingchange).
`test/legacy_word_display_field_revisions_test.dart` independently assembles the
binary records and projects accepted/rejected output XML into different literal
results. It also checks field nesting, private ancestors, repeated records,
false flags, immutable source evidence and malformed/conflicting records. These
checks establish native structure and cached states, not a renderer's ability
to recalculate LISTNUM or expose its full editing interface.

## Comment threads and ink evidence

Validated `ATRDPost10` / `AtrdExtra` records map to native `comments.xml` and
`commentsExtended.xml` parts. Reply relationships join the *last paragraph's*
`w14:paraId` for each comment. Multi-paragraph comments retain all paragraphs;
public model input may list a reply before its parent. Binary records follow the
specified pre-order and exact depth/relative-parent relation. Cycles, missing
parents, excess depth, wrong record lengths and non-preorder binary trees are
rejected.

The original 18-byte extended record is immutable in the public model and copied
into an inert evidence part with its Table-stream offset. The ink-annotation bit
is retained. Already supported referenced images/objects in comment stories use
the normal media paths; the ink bit alone is never turned into invented strokes
or an active `o:ink` element. Proprietary pen-stroke data is not decoded. The
record does not encode a resolved/done state, so none is fabricated in the native
thread part. A hidden/private parent keeps its reply branch inert as well.

## Remaining limits

Table/row/cell formatting history, moves, and
multi-step editing history are not reconstructed as native tracked changes.
One binary wall contains one prior
property snapshot, not an arbitrary revision log. Revision reasons are exposed
as source codes; they are not converted into invented user-visible edits.
No change is accepted automatically. Formatting histories for unsupported
properties remain a limitation even when a native revision element is written
for the supported subset.

Section decoding follows [MS-DOC section properties](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/46c3ec54-53ff-4c0a-b0d6-07ad15d2546e),
and native history follows [SectionPropertiesChange](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.wordprocessing.sectionpropertieschange)
and [PreviousSectionProperties](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.wordprocessing.previoussectionproperties).
`test/legacy_word_section_revisions_test.dart` independently assembles the binary
records and applies accept/reject property rules to parsed XML to verify both
states, including section-break ownership, unequal columns, conflicting authors,
missing snapshots and malformed historical values. These are semantic tests;
they do not certify Microsoft Word's pagination or its user-interface behavior.

The opt-in `tool/fidelity/section_review_probe.py` creates an independently
authored binary fixture and reports native source-DOC and converted-DOCX review
loss separately. On LibreOfficeDev 26.8 build
`2c87e51eeaa2b413ff4ae097b2705eea1995d8e5`, both native imports dropped the
fixture's section revisions; our direct output retained two (including the
break shifted onto the following section). That renderer is therefore not a
positive oracle for retention of section review data. Reports keep the source
hash, source expectations and all measured section states.
The probe enforces the pinned fixture hash and the independently authored current
and previous properties before accepting the parser result. Adversarial tests
ensure that losing revisions in all three routes cannot become a passing golden.

Numbering history follows [MS-DOC NumRM](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/3311b346-4291-419c-be53-34e98d809d76),
[NumRMOperand](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/347cc059-c0cf-481e-847b-5130b7f215a9),
the paragraph-property preservation rules, and the native
[NumberingChange grammar](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.wordprocessing.numberingchange).
`test/legacy_word_numbering_revisions_test.dart` assembles independent binary
records, evaluates old multilevel labels from the output grammar, and checks
insertion versus ordinary paragraph text, list removal, style resets, PRM0,
immutable source evidence and malformed extents.

Full paired-move semantics must be tested on an OOXML source path: the
[MS-DOC FibRgFcLcb2007 definition](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/f04ad697-5027-46c0-bf4c-52fc7843a2f6)
requires the reserved MoveFrom/MoveTo lengths to be zero and their offsets to be
ignored. Matching insertion/deletion text is not enough to invent a move pair.

## Specification and tests

The implementation is authored against Microsoft [MS-DOC Character
Properties](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/7022285b-9621-42e9-ad4d-4e02c115ef18),
[PropRMark](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/2380efe1-d272-44cf-896f-9ead7f576dc9),
and [MS-DOC §§2.6.1–2.6.2 (2019 published
revision)](https://officeprotocoldoc.z19.web.core.windows.net/files/MS-DOC/%5BMS-DOC%5D-190319.pdf).
The older paragraph-record opcode is also documented in Microsoft's
[Word 97–2007 binary-format
specification](https://download.microsoft.com/download/0/b/e/0be8bdd7-e5e8-422a-abfd-4342ed7ad886/word97-2007binaryfileformat%28doc%29specification.pdf).
Native markup follows the Open XML specification's
[revision model](https://learn.microsoft.com/en-us/office/open-xml/word/how-to-accept-all-revisions-in-a-word-processing-document);
that guide is used as a structural reference, not to accept changes.

`test/legacy_word_revisions_test.dart` independently assembles binary SPRMs,
FKPs and author records. It checks current/previous properties, style-reset
ordering, overlapping authors, paragraph marks, malformed lengths/Boolean
operands, privacy, and the independently parsed output XML.

Thread serialization follows [MS-DOC AtrdExtra](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/1b6a50f8-de0c-4020-bce0-06e24660c928),
[ATRDPost10](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/19181fe7-a62a-4e70-9a5f-a0cb1ebe0921)
and the current Open XML [CommentEx last-paragraph
join](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.office2013.word.commentex?view=openxml-3.0.1).
`test/legacy_word_comment_threads_test.dart` uses independent binary records and
ZIP/XML assertions for the join, content types/relationships, source bytes,
privacy, input order and malformed graphs. Native ink uses a separate
[Ink Serialized Format](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-oi29500/05ab37ae-e14e-424c-808e-6748b131c121);
the current comment-record evidence is not a reconstruction of that format.
