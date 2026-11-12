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

## Residual scope

Floating-table placement, table-style conditional formatting and list-instance
continuation need their own property-level interpretation. Retaining nested
content alone does not establish page-layout equivalence to Microsoft Word.
