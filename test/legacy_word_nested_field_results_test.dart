// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:legacy_doc_parser/legacy_doc_parser.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'support/story_word_fixture.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

XmlDocument _xml(Uint8List bytes) => XmlDocument.parse(
  utf8.decode(
    ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content,
  ),
);

List<String> _markers(XmlDocument xml) => [
  for (final element in xml.findAllElements('fldChar', namespace: _w))
    element.getAttribute('fldCharType', namespace: _w)!,
];

String _text(XmlDocument xml) => xml
    .findAllElements('t', namespace: _w)
    .map((element) => element.innerText)
    .join();

// Independently project complex-field XML: text is visible only after every
// enclosing field's separator. No instruction or field evaluation is involved.
String _visibleText(XmlDocument xml) {
  final result = StringBuffer();
  final results = <bool>[];
  for (final run in xml.findAllElements('r', namespace: _w)) {
    final marker = run.getElement('fldChar', namespace: _w);
    if (marker != null) {
      switch (marker.getAttribute('fldCharType', namespace: _w)) {
        case 'begin':
          results.add(false);
        case 'separate':
          expect(results, isNotEmpty);
          results[results.length - 1] = true;
        case 'end':
          expect(results, isNotEmpty);
          results.removeLast();
      }
    } else if (results.every((value) => value)) {
      for (final text in run.findElements('t', namespace: _w)) {
        result.write(text.innerText);
      }
    }
  }
  expect(results, isEmpty);
  return result.toString();
}

List<int> _fieldPlc(String text, Set<int> privateEnds) {
  final positions = <int>[], records = <int>[];
  var depth = 0;
  for (var cp = 0; cp < text.length; cp++) {
    final unit = text.codeUnitAt(cp);
    if (!const [19, 20, 21].contains(unit)) continue;
    positions.add(cp);
    var flags = 0;
    if (unit == 19) depth++;
    if (unit == 21) {
      flags =
          0x80 | (depth > 1 ? 0x40 : 0) | (privateEnds.contains(cp) ? 0x20 : 0);
      depth--;
    }
    records.addAll([unit, flags]);
  }
  return storyPlc([...positions, 0xffffffff], records);
}

void main() {
  test('nested cached results stay inside the enclosing field instruction', () {
    const source =
        'A\x13 IF \x13 REF Name \x14pre\x13 PAGE \x142\x15post\x15 '
        '= "pre2post" "yes" "no" \x14Visible\x15Z\r';
    final bytes = storyWordFixture(main: source);
    final original = Uint8List.fromList(bytes);
    final document = parseLegacyWordDocument(bytes);
    expect(
      document.fields.singleWhere((field) => field.type == 'REF').storedResult,
      'pre2post',
    );
    final converted = convertLegacyWordDocument(document);
    final xml = _xml(converted.bytes);
    expect(_markers(xml), [
      'begin',
      'begin',
      'separate',
      'begin',
      'separate',
      'end',
      'end',
      'separate',
      'end',
    ]);
    expect(_text(xml), 'Apre2postVisibleZ');
    expect(_visibleText(xml), 'AVisibleZ');
    expect(converted.preservedCounts['fields'], 3);
    expect(bytes, orderedEquals(original));
  });

  test(
    'private results do not emit nested instruction text or field markers',
    () {
      const source =
          'A\x13 REF Hidden \x14before\x13 QUOTE "PrivateInstruction" '
          '\x14PrivateResult\x15after\x15Z\r';
      final converted = convertLegacyWordToStructuredDocx(
        storyWordFixture(
          main: source,
          tablePairs: {
            16: _fieldPlc(source, {source.lastIndexOf('\x15')}),
          },
        ),
      );
      final xml = _xml(converted.bytes);
      expect(_markers(xml), ['begin', 'separate', 'end']);
      expect(_text(xml), 'AZ');
      expect(xml.toXmlString(), isNot(contains('Private')));
      expect(converted.preservedCounts['fields'], 1);
    },
  );

  test(
    'private nested instruction results remain empty across deeper fields',
    () {
      const source =
          'A\x13 IF \x13 REF Hidden \x14before\x13 QUOTE "PrivateInstruction" '
          '\x14PrivateResult\x15after\x15 = "" "yes" "no" '
          '\x14Visible\x15Z\r';
      final privateEnd = source.indexOf(' =') - 1;
      final converted = convertLegacyWordToStructuredDocx(
        storyWordFixture(
          main: source,
          tablePairs: {
            16: _fieldPlc(source, {privateEnd}),
          },
        ),
      );
      final xml = _xml(converted.bytes);
      expect(_markers(xml), [
        'begin',
        'begin',
        'separate',
        'end',
        'separate',
        'end',
      ]);
      expect(_text(xml), 'AVisibleZ');
      expect(_visibleText(xml), 'AVisibleZ');
      expect(xml.toXmlString(), isNot(contains('Private')));
      expect(converted.preservedCounts['fields'], 2);
    },
  );

  test(
    'unsupported nested result fields retain only cached text and evidence',
    () {
      const source =
          'A\x13 IF \x13 REF Name \x14pre\x13 INCLUDETEXT "https://invalid.test/" '
          '\x14cached\x15post\x15 = "precachedpost" "yes" "no" '
          '\x14Visible\x15Z\r';
      final converted = convertLegacyWordToStructuredDocx(
        storyWordFixture(main: source),
      );
      final xml = _xml(converted.bytes);
      expect(_markers(xml), [
        'begin',
        'begin',
        'separate',
        'end',
        'separate',
        'end',
      ]);
      expect(_text(xml), 'AprecachedpostVisibleZ');
      expect(_visibleText(xml), 'AVisibleZ');
      expect(xml.toXmlString(), isNot(contains('INCLUDETEXT')));
      expect(converted.preservedCounts['fields'], 2);
      expect(
        converted.limitations,
        contains(LegacyWordConversionLimitation.fieldsLists),
      );
      final manifest = utf8.decode(
        ZipDecoder()
            .decodeBytes(converted.bytes)
            .findFile('word/evidence/manifest.json')!
            .content,
      );
      expect(manifest, contains('INCLUDETEXT'));
    },
  );
}
