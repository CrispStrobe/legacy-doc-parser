// SPDX-License-Identifier: MPL-2.0

import 'package:legacy_doc_parser/legacy_doc_parser.dart';

const publicCharacterScopes = [
  'run',
  'mark',
  'revision',
  'line-number',
  'note-reference',
  'note-marker',
  'list-marker',
];
const publicParagraphScopes = ['paragraph', 'revision', 'list-marker'];

const invalidPublicCharacters = <String, LegacyWordCharacterStyle>{
  'font-size-zero': LegacyWordCharacterStyle(fontSizeHalfPoints: 0),
  'font-size-small': LegacyWordCharacterStyle(fontSizeHalfPoints: 1),
  'font-size-high': LegacyWordCharacterStyle(fontSizeHalfPoints: 3277),
  'position-low': LegacyWordCharacterStyle(positionHalfPoints: -3169),
  'position-high': LegacyWordCharacterStyle(positionHalfPoints: 3169),
  'character-spacing-low': LegacyWordCharacterStyle(spacingTwips: -32769),
  'character-spacing-high': LegacyWordCharacterStyle(spacingTwips: 32768),
};
const validPublicCharacters = <String, LegacyWordCharacterStyle>{
  'unspecified': LegacyWordCharacterStyle(),
  'font-size-min': LegacyWordCharacterStyle(fontSizeHalfPoints: 2),
  'font-size-max': LegacyWordCharacterStyle(fontSizeHalfPoints: 3276),
  'position-min': LegacyWordCharacterStyle(positionHalfPoints: -3168),
  'position-max': LegacyWordCharacterStyle(positionHalfPoints: 3168),
  'character-spacing-min': LegacyWordCharacterStyle(spacingTwips: -32768),
  'character-spacing-max': LegacyWordCharacterStyle(spacingTwips: 32767),
};
const invalidPublicParagraphs = <String, LegacyWordParagraphStyle>{
  'heading-zero': LegacyWordParagraphStyle(headingLevel: 0),
  'heading-high': LegacyWordParagraphStyle(headingLevel: 10),
  'before-low': LegacyWordParagraphStyle(spaceBeforeTwips: -1),
  'before-high': LegacyWordParagraphStyle(spaceBeforeTwips: 65536),
  'after-low': LegacyWordParagraphStyle(spaceAfterTwips: -1),
  'after-high': LegacyWordParagraphStyle(spaceAfterTwips: 65536),
  'left-low': LegacyWordParagraphStyle(leftIndentTwips: -32769),
  'left-high': LegacyWordParagraphStyle(leftIndentTwips: 32768),
  'right-low': LegacyWordParagraphStyle(rightIndentTwips: -32769),
  'right-high': LegacyWordParagraphStyle(rightIndentTwips: 32768),
  'first-low': LegacyWordParagraphStyle(firstLineIndentTwips: -32769),
  'first-high': LegacyWordParagraphStyle(firstLineIndentTwips: 32768),
  'line-low': LegacyWordParagraphStyle(lineSpacingValue: -32769),
  'line-high': LegacyWordParagraphStyle(lineSpacingValue: 32768),
};
const validPublicParagraphs = <String, LegacyWordParagraphStyle>{
  'unspecified': LegacyWordParagraphStyle(),
  'heading-min': LegacyWordParagraphStyle(headingLevel: 1),
  'heading-max': LegacyWordParagraphStyle(headingLevel: 9),
  'before-max': LegacyWordParagraphStyle(spaceBeforeTwips: 65535),
  'after-max': LegacyWordParagraphStyle(spaceAfterTwips: 65535),
  'indent-min': LegacyWordParagraphStyle(
    leftIndentTwips: -32768,
    rightIndentTwips: -32768,
    firstLineIndentTwips: -32768,
  ),
  'indent-max': LegacyWordParagraphStyle(
    leftIndentTwips: 32767,
    rightIndentTwips: 32767,
    firstLineIndentTwips: 32767,
  ),
  'line-min': LegacyWordParagraphStyle(lineSpacingValue: -32768),
  'line-max': LegacyWordParagraphStyle(lineSpacingValue: 32767),
};

LegacyWordDocument publicFormattingDocument({
  required String scope,
  LegacyWordCharacterStyle? character,
  LegacyWordParagraphStyle? paragraph,
}) {
  final hasNote = scope == 'note-reference' || scope == 'note-marker';
  return LegacyWordDocument(
    blocks: [
      LegacyWordParagraph(
        startCp: 0,
        endCp: 5,
        runs: [
          LegacyWordRun(
            startCp: 0,
            endCp: 4,
            text: 'Body',
            style: scope == 'run' && character != null
                ? character
                : const LegacyWordCharacterStyle(),
            formattingRevision: scope == 'revision' && character != null
                ? LegacyWordCharacterFormattingRevision(
                    previousStyle: character,
                  )
                : null,
          ),
        ],
        style: scope == 'list-marker'
            ? const LegacyWordParagraphStyle(listId: 1)
            : scope == 'paragraph' && paragraph != null
            ? paragraph
            : const LegacyWordParagraphStyle(),
        mark: scope == 'mark' && character != null
            ? LegacyWordParagraphMark(style: character)
            : null,
        formattingRevision: scope == 'revision' && paragraph != null
            ? LegacyWordParagraphFormattingRevision(previousStyle: paragraph)
            : null,
      ),
    ],
    sections: const [],
    plainText: 'Body',
    safeHtml: '',
    lineNumberStyle: scope == 'line-number' ? character : null,
    numbering: [
      if (scope == 'list-marker')
        LegacyWordNumberingDefinition(
          id: 1,
          levels: [
            LegacyWordNumberingLevel(
              level: 0,
              format: 'decimal',
              text: '%1.',
              characterStyle: character ?? const LegacyWordCharacterStyle(),
              paragraphStyle: paragraph ?? const LegacyWordParagraphStyle(),
            ),
          ],
        ),
    ],
    stories: [
      if (hasNote)
        const LegacyWordStory(
          id: 'note',
          kind: LegacyWordStoryKind.footnote,
          startCp: 100,
          endCp: 105,
          blocks: [
            LegacyWordParagraph(
              startCp: 100,
              endCp: 105,
              runs: [LegacyWordRun(startCp: 100, endCp: 104, text: 'Note')],
            ),
          ],
          plainText: 'Note',
          safeHtml: '',
        ),
    ],
    noteReferences: [
      if (hasNote)
        LegacyWordNoteReference(
          id: 1,
          anchorCp: 1,
          storyId: 'note',
          endnote: false,
          referenceStyle: scope == 'note-reference' ? character : null,
          markerStyle: scope == 'note-marker' ? character : null,
        ),
    ],
  );
}
