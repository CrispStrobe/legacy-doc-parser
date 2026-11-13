// SPDX-License-Identifier: MPL-2.0
// Pure Dart acceptance for the actual retained DOCs under dart2js/Node.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:legacy_doc_parser/legacy_doc_parser.dart';
import 'package:xml/xml.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}

Map<String, Object?> verifyFieldMetadataWebAcceptance(List cases) {
  _check(
    cases.length == 2,
    'Both independent native field sources are required',
  );
  final results = <String, Object?>{};
  for (final entry in cases) {
    final name = entry['name'] as String;
    _check(!results.containsKey(name), 'Unique field source');
    _check(name == 'external' || name == 'reference', 'Known field source');
    final source = base64Decode(entry['base64'] as String);
    final before = Uint8List.fromList(source);
    final result = convertLegacyWord(source);
    final zip = ZipDecoder().decodeBytes(result.bytes);
    final parts = <String, XmlDocument>{
      for (final part in zip)
        if (part.name.startsWith('word/') &&
            part.name.endsWith('.xml') &&
            part.name.split('/').length == 2)
          part.name: XmlDocument.parse(utf8.decode(part.content)),
    };
    final instructions = parts.values
        .expand((p) => p.findAllElements('instrText', namespace: _w))
        .map((e) => e.innerText)
        .toList();
    for (final part in parts.values) {
      for (final begin in part.findAllElements('fldChar', namespace: _w)) {
        if (begin.getAttribute('fldCharType', namespace: _w) == 'begin') {
          _check(
            begin.getAttribute('fldLock', namespace: _w) == '1',
            'Cached field lock',
          );
        }
      }
    }
    if (name == 'external') {
      _check(instructions.length == 4, 'All body/note/header URL fields');
      _check(
        instructions
                .where((s) => s == ' HYPERLINK "https://example.com/body" ')
                .length ==
            1,
        'Body URL',
      );
      _check(
        instructions
                .where((s) => s == ' HYPERLINK "https://example.com/note" ')
                .length ==
            1,
        'Footnote URL',
      );
      _check(
        instructions
                .where((s) => s == ' HYPERLINK "https://example.com/header" ')
                .length ==
            2,
        'Both header URL occurrences',
      );
      _check(
        result.preservedCounts['binaryHyperlinkFields'] == 4,
        'Qualified URL count',
      );
    } else {
      _check(
        instructions.length == 3,
        'REF, internal hyperlink and QUOTE fields',
      );
      _check(instructions[0] == ' REF Target_A \\h  ', 'Reference target');
      final visible = parts['word/document.xml']!
          .findAllElements('t', namespace: _w)
          .map((e) => e.innerText)
          .join();
      _check(
        visible ==
            'ANCHOR-αREF:[CACHED-REF]LINK:[CACHED-LINK]QUOTE:[CACHED-QUOTE]',
        'Original cached reference results',
      );
      _check(
        result.preservedCounts['binaryReferenceFields'] == 1,
        'Qualified REF count',
      );
      _check(
        result.preservedCounts['binaryHyperlinkFields'] == 1,
        'Internal hyperlink count',
      );
      final evidence =
          jsonDecode(
                utf8.decode(
                  zip.findFile('word/evidence/manifest.json')!.content,
                ),
              )
              as Map;
      final record =
          (evidence['records'] as List).singleWhere(
                (r) => r['kind'] == 'binaryReferenceField',
              )
              as Map;
      _check(
        record['recoveredNativeTerminator'] == true,
        'Producer padding is disclosed',
      );
    }
    _check(source.length == before.length, 'Source length');
    for (var i = 0; i < source.length; i++) {
      _check(source[i] == before[i], 'Source bytes unchanged');
    }
    results[name] = {
      'fields': instructions.length,
      'sourceBytesUnchanged': true,
      'representation': 'lockedFields',
    };
  }
  return {'cases': results, 'fields': 7, 'fieldResultsEvaluated': false};
}
