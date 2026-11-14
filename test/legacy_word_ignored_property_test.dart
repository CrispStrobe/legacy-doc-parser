// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:legacy_doc_parser/legacy_doc_parser.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'support/ignored_property_fixture.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

XmlDocument _xml(Uint8List bytes) => XmlDocument.parse(
  utf8.decode(
    ZipDecoder()
        .decodeBytes(convertLegacyWordToStructuredDocx(bytes).bytes)
        .findFile('word/document.xml')!
        .content,
  ),
);

void main() {
  for (final level in [9, 10, 11, 13, 255]) {
    for (final mode in ignoredListLevelModes) {
      test('ignores inapplicable list level $level in $mode properties', () {
        final bytes = ignoredListLevelFixture(level, mode);
        final before = Uint8List.fromList(bytes);
        final document = parseLegacyWordDocument(bytes);
        final paragraph = document.blocks.single as LegacyWordParagraph;
        expect(paragraph.style.listLevel, isNull);
        expect(document.plainText, 'Text');
        expect(_xml(bytes).findAllElements('numPr', namespace: _w), isEmpty);
        expect(bytes, before);
      });
    }
    for (final levelFirst in [false, true]) {
      test('rejects active list level $level with levelFirst=$levelFirst', () {
        expect(
          () => parseLegacyWordDocument(
            activeListLevelFixture(level, levelFirst: levelFirst),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'Invalid Word list level.',
            ),
          ),
        );
      });
    }
  }

  test('historical non-list level is ignored using its own list context', () {
    final bytes = historicalListLevelFixture(previousNumbered: false);
    final document = parseLegacyWordDocument(bytes);
    final paragraph = document.blocks.single as LegacyWordParagraph;
    expect(paragraph.style.listLevel, 0);
    expect(paragraph.formattingRevision!.previousStyle!.listLevel, isNull);
    expect(
      _xml(bytes)
          .findAllElements('ilvl', namespace: _w)
          .map((e) => e.getAttribute('val', namespace: _w)),
      everyElement('0'),
    );
  });
  test('historical active invalid list level remains rejected', () {
    expect(
      () => parseLegacyWordDocument(
        historicalListLevelFixture(previousNumbered: true),
      ),
      throwsFormatException,
    );
  });
  for (final level in [0, 8, 12]) {
    test('defined list-level boundary $level remains accepted', () {
      expect(
        () => parseLegacyWordDocument(activeListLevelFixture(level)),
        returnsNormally,
      );
    });
  }

  for (final mode in ignoredBorderModes) {
    for (final old in [false, true]) {
      test('BrcType FF preserves $mode border, old=$old', () {
        final bytes = ignoredBorderFixture(mode, old: old);
        final before = Uint8List.fromList(bytes);
        final document = parseLegacyWordDocument(bytes);
        if (mode.startsWith('paragraph-')) {
          final paragraph = document.blocks.single as LegacyWordParagraph;
          if (mode == 'paragraph-absent') {
            expect(paragraph.style.borders, isEmpty);
            expect(_xml(bytes).findAllElements('pBdr', namespace: _w), isEmpty);
          } else {
            final top = paragraph.style.borders[LegacyWordBorderSide.top]!;
            expect((top.style, top.colorHex), ('single', 'FF0000'));
            final output = _xml(
              bytes,
            ).findAllElements('top', namespace: _w).single;
            expect(output.getAttribute('val', namespace: _w), 'single');
            expect(output.getAttribute('color', namespace: _w), 'FF0000');
          }
        } else {
          final table = document.blocks.single as LegacyWordTable;
          final top = table
              .rows
              .single
              .cells
              .single
              .formatting
              .borders[LegacyWordTableBorderSide.top]!;
          expect((top.style, top.colorHex), ('single', 'FF0000'));
          final tops = _xml(bytes)
              .findAllElements('tcBorders', namespace: _w)
              .expand((e) => e.findElements('top', namespace: _w));
          expect(tops, hasLength(1));
          expect(tops.single.getAttribute('val', namespace: _w), 'single');
          expect(tops.single.getAttribute('color', namespace: _w), 'FF0000');
        }
        expect(bytes, before);
      });
    }
  }
  for (final old in [false, true]) {
    test('genuine NilBrc still clears a cell border, old=$old', () {
      final bytes = ignoredBorderFixture('range', old: old, nil: true);
      final table =
          parseLegacyWordDocument(bytes).blocks.single as LegacyWordTable;
      expect(
        table
            .rows
            .single
            .cells
            .single
            .formatting
            .borders[LegacyWordTableBorderSide.top]!
            .style,
        'nil',
      );
    });
    for (final type in [2, 4, 28, 63, 254]) {
      test('undefined border type $type still rejects, old=$old', () {
        expect(
          () => parseLegacyWordDocument(
            ignoredBorderFixture('range', old: old, ignoredType: type),
          ),
          throwsFormatException,
        );
      });
    }
  }

  test('POI Bug51834 accepts ignored table border descriptors', () {
    final bytes = File(
      'test/fixtures/external/poi-20261114/poi/doc/Bug51834.doc',
    ).readAsBytesSync();
    final before = Uint8List.fromList(bytes);
    final document = parseLegacyWordDocument(bytes);
    expect(document.plainText, isNotEmpty);
    expect(document.blocks.whereType<LegacyWordTable>(), isNotEmpty);
    expect(_xml(bytes).rootElement.localName, 'document');
    expect(bytes, before);
  });
  test('POI seven-column sample ignores a non-list inherited level', () {
    final bytes = File(
      'test/fixtures/external/poi-20261114/poi/doc/57603-seven_columns.doc',
    ).readAsBytesSync();
    final before = Uint8List.fromList(bytes);
    expect(() => parseLegacyWordDocument(bytes), returnsNormally);
    expect(_xml(bytes).rootElement.localName, 'document');
    expect(bytes, before);
  });
  test('POI 56880 zeroed author table remains explicitly nonconforming', () {
    for (final bytes in [
      File(
        'test/fixtures/external/poi-20261114/poi/doc/56880.doc',
      ).readAsBytesSync(),
      invalidAuthorTableFixture(),
    ]) {
      expect(
        () => parseLegacyWordDocument(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Unexpected Word revision-author data.',
          ),
        ),
      );
    }
  });
}
