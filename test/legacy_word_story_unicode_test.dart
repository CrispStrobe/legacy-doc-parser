// SPDX-License-Identifier: MPL-2.0

import 'package:legacy_doc_parser/legacy_doc_parser.dart';
import 'package:test/test.dart';

import 'support/story_word_fixture.dart';
import 'support/structured_word_fixture.dart';

void main() {
  for (final endnote in [false, true]) {
    test(
      'rejects a surrogate pair split across main and ${endnote ? 'endnote' : 'footnote'} stories',
      () {
        final source = storyWordFixture(
          main: 'A\ud83d',
          footnotes: endnote ? '' : '\ude00\r\r',
          endnotes: endnote ? '\ude00\r\r' : '',
          tablePairs: {
            endnote ? 46 : 2: storyPlc([0, 0xffffffff], wordU16(0)),
            endnote ? 47 : 3: storyPlc([0, 2, 0xffffffff]),
          },
        );
        final before = source.toList();
        expect(
          () => parseLegacyWordDocument(source),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('story boundary'),
            ),
          ),
        );
        expect(source, before);
      },
    );
  }

  test(
    'rejects a textbox whose leading surrogate belongs to a spare range',
    () {
      final source = storyWordFixture(
        main: 'A\r',
        textboxes: '\ud83d\ude00\r\r',
        tablePairs: {
          56: storyPlc(
            [0, 1, 3, 4],
            [
              ..._textboxRecord(reusable: true),
              ..._textboxRecord(shape: 77),
              ..._textboxRecord(),
            ],
          ),
        },
      );
      expect(
        () => parseLegacyWordDocument(source),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('story boundary'),
          ),
        ),
      );
    },
  );

  test('valid supplementary characters stay inside their own stories', () {
    const main = 'A\u{1f600}\x02\r', note = '\x02B\u{1f680}\r';
    final source = storyWordFixture(
      main: main,
      footnotes: '$note\r',
      tablePairs: {
        2: storyPlc([3, 0xffffffff], wordU16(1)),
        3: storyPlc([0, note.length, 0xffffffff]),
      },
    );
    final before = source.toList();
    final document = parseLegacyWordDocument(source);
    expect(document.plainText, 'A\u{1f600}');
    expect(document.stories.single.plainText, 'B\u{1f680}');
    for (final paragraph in [
      ...document.blocks.whereType<LegacyWordParagraph>(),
      ...document.stories.single.blocks.whereType<LegacyWordParagraph>(),
    ]) {
      for (final run in paragraph.runs) {
        expect(run.startCp, greaterThanOrEqualTo(paragraph.startCp));
        expect(run.endCp, lessThanOrEqualTo(paragraph.endCp));
      }
    }
    expect(source, before);
    expect(convertLegacyWordDocument(document).bytes, isNotEmpty);
  });
}

List<int> _textboxRecord({int shape = 0, bool reusable = false}) => [
  ...wordU32(1),
  ...wordU32(0),
  ...wordU16(reusable ? 1 : 0),
  ...wordU32(0),
  ...wordU32(shape),
  ...wordU32(0),
];
