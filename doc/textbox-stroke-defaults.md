# Preserve the source textbox line-width default

Word's OfficeArt `lineWidth` property (`0x01CB`) defaults to `0x2535` EMU,
or 0.75 points. The editable-shape writer already materializes that source
default. The textbox writer now does the same when its shape has an enabled
or default-enabled line and no explicit width.

[MS-ODRAW lineWidth](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-odraw/fb88b56e-2c2d-41c2-a0c8-98129e913b89)
defines the default and the inclusive range 0 through `0x0132F540` EMU.
The [Microsoft implementation notes for VML](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-oi29500/d019f23f-5977-43d8-b463-99ba8f6784eb)
record that the standard's stroke-weight default is 1 point whereas Office's
is 0.75 points. Leaving the attribute absent delegates the source decision to
the receiving application.

This mapping preserves explicit zero, an explicit 0.05-point hairline, and
other supported explicit widths. Disabled strokes remain disabled. Negative,
out-of-range and complex binary line-width operands remain unsupported
evidence and cannot be interpreted as an absent property selecting the
default. Caller-built invalid widths reject conversion. The four-sided
wrapping clearance is independent of stroke width.

The retained Word 14 source contains six textbox shapes with enabled lines and
no explicit line width. All six DOCX rectangles therefore carry
`strokeweight="0.75pt"`. Focused tests also require the exact source anchor
offsets and dimensions to remain unchanged; this correction does not subtract
a measured border offset or change textbox heights. General shape effects,
color inheritance, frame-border placement and arbitrary textbox layout remain
separate contracts.
