// SPDX-License-Identifier: MPL-2.0

import 'package:legacy_doc_parser/legacy_doc_parser.dart';
import 'package:test/test.dart';

import '../tool/list_marker_style_web_acceptance.dart';
import 'support/list_marker_style_fixture.dart';

void main() {
  test(
    'marker inheritance and native properties share VM and JS acceptance',
    () {
      expect(verifyListMarkerStyleWebAcceptance(), {
        'cases': 8,
        'nullableInheritance': true,
        'explicitResets': true,
        'nativeMarkerProperties': true,
        'numberingHighlightUsesShading': true,
        'sourceUnchanged': true,
      });
    },
  );

  test('binary nullable override metadata is immutable', () {
    final level = parseLegacyWordDocument(
      listMarkerStyleFixture('explicit-resets'),
    ).numbering.single.levels.single;
    expect(() => level.characterStyleOverrides.clear(), throwsUnsupportedError);
  });
}
