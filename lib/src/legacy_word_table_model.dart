// SPDX-License-Identifier: MPL-2.0
part of 'legacy_word_structured_model.dart';

enum LegacyWordTableCondition {
  firstRow,
  lastRow,
  firstCol,
  lastCol,
  band1Vert,
  band2Vert,
  band1Horz,
  band2Horz,
  neCell,
  nwCell,
  seCell,
  swCell,
}

enum LegacyWordTableBorderSide {
  top,
  left,
  bottom,
  right,
  insideH,
  insideV,
  tl2br,
  tr2bl,
}

enum LegacyWordCellAlignment { top, center, bottom }

/// A supported set of cell properties. Null and absent entries inherit.
class LegacyWordTableCellFormat {
  const LegacyWordTableCellFormat({
    this.shading,
    this.borders = const {},
    this.verticalAlignment,
    this.noWrap,
    this.margins = const {},
  });
  final LegacyWordShading? shading;
  final Map<LegacyWordTableBorderSide, LegacyWordBorder> borders;
  final LegacyWordCellAlignment? verticalAlignment;
  final bool? noWrap;

  /// Missing sides inherit; a present null retains an explicit nil width.
  final Map<LegacyWordBorderSide, int?> margins;
}

/// Native table-style identity and supported cell-level conditional rules.
/// Paragraph/run conditions remain separately diagnosed until their source
/// cascade can be applied before character-run segmentation.
class LegacyWordTableStyle {
  const LegacyWordTableStyle({
    required this.id,
    required this.name,
    this.basedOn,
    this.rowBandSize,
    this.columnBandSize,
    this.cell = const LegacyWordTableCellFormat(),
    this.conditions = const {},
  });
  final int id;
  final String name;
  final int? basedOn;
  final int? rowBandSize;
  final int? columnBandSize;
  final LegacyWordTableCellFormat cell;
  final Map<LegacyWordTableCondition, LegacyWordTableCellFormat> conditions;
}
