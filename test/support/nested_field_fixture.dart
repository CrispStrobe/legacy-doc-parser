// SPDX-License-Identifier: MPL-2.0
import 'dart:typed_data';

import 'story_word_fixture.dart';

const _sources = {
  'nested-results':
      'A\x13 IF \x13 REF Name \x14pre\x13 PAGE \x142\x15post\x15 '
      '= "pre2post" "yes" "no" \x14Visible\x15Z\r',
  'private-result':
      'A\x13 REF Hidden \x14before\x13 QUOTE "PrivateInstruction" '
      '\x14PrivateResult\x15after\x15Z\r',
  'private-instruction-result':
      'A\x13 IF \x13 REF Hidden \x14before\x13 QUOTE "PrivateInstruction" '
      '\x14PrivateResult\x15after\x15 = "" "yes" "no" '
      '\x14Visible\x15Z\r',
  'unsupported-result':
      'A\x13 IF \x13 REF Name \x14pre\x13 INCLUDETEXT "https://invalid.test/" '
      '\x14cached\x15post\x15 = "precachedpost" "yes" "no" '
      '\x14Visible\x15Z\r',
};

const nestedFieldCases = [
  'nested-results',
  'private-result',
  'private-instruction-result',
  'unsupported-result',
];

/// Independently assembled binary controls shared by VM, JS and schema gates.
Uint8List nestedFieldFixture(String name) {
  final source = _sources[name];
  if (source == null) throw ArgumentError.value(name, 'name');
  return storyWordFixture(
    main: source,
    tablePairs: {
      if (name == 'private-result')
        16: _fieldPlc(source, {source.lastIndexOf('\x15')}),
      if (name == 'private-instruction-result')
        16: _fieldPlc(source, {source.indexOf(' =') - 1}),
    },
  );
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
