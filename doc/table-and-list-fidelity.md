# Table and list fidelity

The parser keeps source character positions and never rewrites the input DOC.
The following behavior is covered by independently assembled binary fixtures
and by inspection of the emitted WordprocessingML.

## Nested tables

`LegacyWordTableCell.blocks` preserves paragraphs and nested tables in source
order. The existing `paragraphs` getter/field remains the direct paragraphs of
the cell; a complete-content consumer should visit `blocks` recursively.

The parser applies `sprmPItap` and signed `sprmPDtap` changes in order. It checks
the depth-specific cell and row markers, row cell definitions and the limit of
63 nesting levels and 63 cells per row. Incomplete rows and inconsistent markers
fail explicitly. A child table may be the first content in its enclosing cell.
HTML and DOCX retain that structure, and DOCX cells ending in a table receive
the required final paragraph.

This follows [MS-DOC, Overview of Tables](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/5b45f0e7-7760-4fdb-af88-0146de2feb4c)
and [Direct Paragraph Formatting](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/61b635c3-2c44-4155-bf17-fec281b30c71).

Tests: `test/legacy_word_nested_tables_test.dart`. The binary fixture is
assembled without using the production parser or DOCX writer.

## Row origins and a shared table grid

`LegacyWordTableRow.originTwips` retains the signed first `rgdxaCenter` edge
from `sprmTDefTable`. The ordered `sprmTDxaLeft` and `sprmTDxaGapHalf` properties
can subsequently move that origin without changing individual cell widths.
Negative origins remain negative: the native fixture's 108-twip outdent must
not silently become zero and shift every cell's text by 5.4 points.

DOCX writes the origin as `w:tblInd` and constructs its grid from the absolute
edges of all rows. Rows beginning or ending inside that grid retain their
missing leading or trailing cells through `w:gridBefore`/`w:gridAfter` and
`w:wBefore`/`w:wAfter`. Differently split and indented rows therefore share a
grid without inventing content cells. This is property preservation; exact
placement still needs an independently rendered comparison.

References: [TDefTableOperand](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/de06ec41-a0ac-4046-9096-cdfaa0091ad9)
and [Table Properties](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/b39a6648-501c-4361-8366-4f042f579469).
Tests: `test/legacy_word_table_origin_test.dart`.

### Nonconforming exporter recovery

A LibreOffice bridge fixture (`word-compatibility.doc`) contains a `cb=0`
PAPX ending with one stray byte after otherwise complete properties. The
parser accepts exactly this case and reports
`recoveredNonconformingProperties` plus `unsupportedFormatting`. It does not
retain the orphan's value as a supported property or claim this is legal
padding. The recovery does not apply to CHPX, styles or indirect properties,
and never repairs a truncated operand or extended-length record.

[PapxInFkp](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/580510b8-df7a-467e-a51c-0d71eb15c7cd)
declares the entire two-byte-aligned extent, while
[GrpPrlAndIstd](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/bd96f2aa-1318-4066-9723-4db035ef412b)
requires whole property records. The warning therefore identifies an exporter
compatibility recovery, not a change to those extents. Focused positive and
negative cases are in `test/legacy_word_fkp_recovery_test.dart`.

## Shared list-instance continuation

The source `lsid` identifies the number sequence even when paragraphs alternate
between distinct `ilfo` instances. When every instance for an `lsid` has no
level overrides, the parser records the shared sequence using
`LegacyWordNumberingDefinition.continuationOf`. Original instance ids and signed
paragraph `listId` values remain intact. HTML shares its counter and DOCX maps
the instances to one editable `w:num`; conversion evidence records that mapping.
Numbering continues across intervening paragraphs and does not depend on which
instance is encountered first.

Groups that include start or formatting overrides still report
`numberingNotReconstructed`. The first-use override and per-level restart rules
require more than grouping by `lsid`; those instances are not silently merged.
Public continuation references must name an unchained definition with the same
source id and shared level objects, preventing a continuation from discarding
different formatting.

Reference: [Determining Level Number of a Paragraph](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-doc/361e48e1-ae56-4b62-a950-01664b2cc006).
Tests: `test/legacy_word_list_continuation_test.dart`.

## Residual scope

Floating-table placement, table-style conditional formatting and list-instance
continuation with overrides need their own property-level interpretation. Retaining nested
content alone does not establish page-layout equivalence to Microsoft Word.
