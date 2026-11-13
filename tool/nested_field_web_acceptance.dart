// SPDX-License-Identifier: MPL-2.0
// The same binary field cases run on the VM, in compiled JS and through the
// independent Open XML SDK gate. No field instructions are evaluated.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:legacy_doc_parser/legacy_doc_parser.dart';
import 'package:xml/xml.dart';

import '../test/support/nested_field_fixture.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

void _check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

Map<String, Object?> verifyNestedFieldWebAcceptance() {
  const fieldCounts = {
    'nested-results': 3,
    'private-result': 1,
    'private-instruction-result': 2,
    'unsupported-result': 2,
    'formula': 1,
  };
  for (final name in nestedFieldCases) {
    final source = nestedFieldFixture(name);
    final before = Uint8List.fromList(source);
    final result = convertLegacyWordToStructuredDocx(source);
    final archive = ZipDecoder().decodeBytes(result.bytes);
    final text = utf8.decode(archive.findFile('word/document.xml')!.content);
    final document = XmlDocument.parse(text);
    final states = <bool>[];
    final visible = StringBuffer();
    var fields = 0;
    // Project display text from the emitted complex-field grammar, independent
    // of the parser's normalized storedResult and its source-CP representation.
    for (final run in document.findAllElements('r', namespace: _w)) {
      final marker = run.getElement('fldChar', namespace: _w);
      if (marker != null) {
        switch (marker.getAttribute('fldCharType', namespace: _w)) {
          case 'begin':
            states.add(false);
            fields++;
          case 'separate':
            _check(states.isNotEmpty && !states.last, '$name separator');
            states[states.length - 1] = true;
          case 'end':
            _check(states.isNotEmpty, '$name field end');
            states.removeLast();
          default:
            throw StateError('$name unknown field marker');
        }
      } else if (states.every((state) => state)) {
        for (final item in run.findElements('t', namespace: _w)) {
          visible.write(item.innerText);
        }
      }
    }
    _check(states.isEmpty, '$name unclosed fields');
    _check(fields == fieldCounts[name], '$name duplicated/missing fields');
    _check(result.preservedCounts['fields'] == fields, '$name field counts');
    final expectedText = switch (name) {
      'private-result' => 'AZ',
      'formula' => 'A999Z',
      _ => 'AVisibleZ',
    };
    _check(visible.toString() == expectedText, '$name visible field result');
    if (name == 'formula') {
      _check(
        document.findAllElements('instrText', namespace: _w).single.innerText ==
            ' = 1 + 1 ',
        'formula instruction',
      );
      _check(
        document
                .findAllElements('fldChar', namespace: _w)
                .first
                .getAttribute('fldLock', namespace: _w) ==
            '1',
        'formula must remain locked without evaluation',
      );
    }
    _check(!text.contains('Private'), '$name private descendant escaped');
    _check(!text.contains('INCLUDETEXT'), '$name external field activated');
    if (name == 'unsupported-result') {
      final evidence = utf8.decode(
        archive.findFile('word/evidence/manifest.json')!.content,
      );
      _check(evidence.contains('INCLUDETEXT'), '$name missing inert evidence');
    }
    for (final part in archive) {
      if (!part.name.endsWith('.rels')) continue;
      final relationships = XmlDocument.parse(utf8.decode(part.content));
      _check(
        relationships.rootElement.childElements.every(
          (element) => element.getAttribute('TargetMode') != 'External',
        ),
        '$name external package relationship',
      );
    }
    _check(source.length == before.length, '$name source length');
    for (var index = 0; index < source.length; index++) {
      _check(source[index] == before[index], '$name source mutation');
    }
  }
  return {
    'cases': nestedFieldCases.length,
    'fieldCounts': fieldCounts,
    'balancedFields': true,
    'privateDescendantsSuppressed': true,
    'externalFieldsInert': true,
    'sourceUnchanged': true,
  };
}
