// SPDX-License-Identifier: MPL-2.0

import 'package:legacy_doc_parser/legacy_doc_parser.dart';

const publicTextboxInvalidCases = [
  'duplicate-story',
  'duplicate-story-unplaced',
  'duplicate-drawing',
  'zero-id',
  'negative-id',
  'wrong-story-kind',
  'zero-length',
  'excessive-length',
  'count-mismatch',
  'gap-index',
  'duplicate-index',
  'negative-index',
  'wrong-first-shape',
  'wrong-first-anchor',
  'wrong-next-shape',
  'cycle',
  'duplicate-anchor',
  'wrong-drawing-id',
  'wrong-drawing-index',
  'wrong-drawing-next',
  'invalid-recovery-length',
  'unproved-recovery',
];

const publicTextboxValidCases = [
  'single',
  'single-without-client',
  'chain',
  'chain-reversed',
  'chain-null-links',
  'chain-zero-links',
  'recovered-chain',
  'unresolved-chain',
  'two-stories',
  'two-stories-reversed',
];

LegacyWordDocument publicTextboxReferenceDocument(String mutation) {
  final twoReferences =
      mutation.startsWith('duplicate-') &&
          mutation != 'duplicate-index' &&
          mutation != 'duplicate-anchor' ||
      mutation.startsWith('two-stories');
  final sameStory = mutation.startsWith('duplicate-story');
  final sameDrawing = mutation == 'duplicate-drawing';
  final single =
      mutation.startsWith('single') ||
      twoReferences ||
      const [
        'zero-id',
        'negative-id',
        'wrong-story-kind',
        'zero-length',
        'excessive-length',
      ].contains(mutation);
  var chainLength = single ? 1 : 2;
  if (mutation == 'zero-length') chainLength = 0;
  if (mutation == 'excessive-length') chainLength = 4097;
  if (mutation == 'count-mismatch') chainLength = 3;
  final firstId = mutation == 'zero-id'
      ? 0
      : mutation == 'negative-id'
      ? -1
      : 1;
  final firstIndex = mutation == 'negative-index' ? -1 : 0;
  final secondIndex = mutation == 'gap-index'
      ? 2
      : mutation == 'duplicate-index'
      ? 0
      : 1;
  final int? firstNext = switch (mutation) {
    'chain-null-links' || 'unproved-recovery' => null,
    'chain-zero-links' => 0,
    'wrong-next-shape' => 99,
    _ => single ? null : 43,
  };
  final int? secondNext = mutation == 'cycle'
      ? 42
      : mutation == 'chain-zero-links'
      ? 0
      : null;
  final anchors = <LegacyWordTextboxAnchor>[
    LegacyWordTextboxAnchor(
      shapeId: 42,
      anchorCp: 1,
      chainIndex: firstIndex,
      nextShapeId: firstNext,
    ),
    if (!single)
      LegacyWordTextboxAnchor(
        shapeId: mutation == 'duplicate-anchor' ? 42 : 43,
        anchorCp: mutation == 'duplicate-anchor' ? 1 : 3,
        chainIndex: secondIndex,
        nextShapeId: secondNext,
      ),
  ];
  final first = LegacyWordTextboxReference(
    id: firstId,
    storyId: 'box-1',
    inHeaderFooter: false,
    shapeId: mutation == 'wrong-first-shape' ? 43 : 42,
    anchorCp: mutation == 'duplicate-story-unplaced'
        ? 50
        : mutation == 'wrong-first-anchor'
        ? 2
        : mutation == 'wrong-first-shape'
        ? 3
        : 1,
    chainLength: chainLength,
    declaredChainLength: mutation == 'invalid-recovery-length'
        ? 2
        : const ['recovered-chain', 'unproved-recovery'].contains(mutation)
        ? 1
        : null,
    anchors: mutation == 'unresolved-chain' || single
        ? const []
        : mutation == 'chain-reversed'
        ? anchors.reversed.toList()
        : anchors,
  );
  final second = LegacyWordTextboxReference(
    id: 2,
    storyId: sameStory ? 'box-1' : 'box-2',
    inHeaderFooter: false,
    shapeId: sameDrawing ? 42 : 43,
    anchorCp: sameDrawing ? 1 : 3,
  );
  LegacyWordParagraph paragraph(int cp, String text) => LegacyWordParagraph(
    startCp: cp,
    endCp: cp + text.length + 1,
    runs: [LegacyWordRun(startCp: cp, endCp: cp + text.length, text: text)],
  );
  LegacyWordDrawing drawing(int shapeId, int cp, int index, int storyId) =>
      LegacyWordDrawing(
        shapeId: shapeId,
        anchorCp: cp,
        headerStory: false,
        leftTwips: index * 1440,
        topTwips: 0,
        rightTwips: (index + 1) * 1440,
        bottomTwips: 720,
        horizontalOrigin: 0,
        verticalOrigin: 0,
        wrapMode: 3,
        wrapSide: 0,
        behindText: false,
        anchorLocked: false,
        textboxId:
            mutation == 'single-without-client' ||
                sameDrawing ||
                mutation == 'unresolved-chain'
            ? null
            : ((mutation == 'wrong-drawing-id' && index == 1 ? 9 : storyId) <<
                      16) |
                  (mutation == 'wrong-drawing-index' && index == 1 ? 2 : index),
        nextTextboxShapeId: mutation == 'wrong-drawing-next' && index == 1
            ? 42
            : single || mutation == 'unresolved-chain'
            ? null
            : index == 0
            ? firstNext
            : secondNext,
        source: const LegacyWordSourceReference(
          streamPath: '0Table',
          offset: 0,
          length: 26,
          structure: 'FSPA',
        ),
      );
  return LegacyWordDocument(
    blocks: [paragraph(0, 'ABCD')],
    sections: const [],
    plainText: 'ABCD',
    safeHtml: '',
    stories: [
      LegacyWordStory(
        id: 'box-1',
        kind: mutation == 'wrong-story-kind'
            ? LegacyWordStoryKind.headerTextbox
            : LegacyWordStoryKind.textbox,
        startCp: 100,
        endCp: 104,
        blocks: [paragraph(100, 'One')],
        plainText: 'One',
        safeHtml: '',
      ),
      if (twoReferences && !sameStory)
        LegacyWordStory(
          id: 'box-2',
          kind: LegacyWordStoryKind.textbox,
          startCp: 200,
          endCp: 204,
          blocks: [paragraph(200, 'Two')],
          plainText: 'Two',
          safeHtml: '',
        ),
    ],
    textboxReferences: [
      if (mutation == 'two-stories-reversed') second,
      first,
      if (twoReferences && mutation != 'two-stories-reversed') second,
    ],
    media: LegacyWordMediaCatalog.from(
      drawings: [
        drawing(42, 1, 0, 1),
        if ((!single || twoReferences) &&
            !sameDrawing &&
            mutation != 'unresolved-chain')
          drawing(43, 3, twoReferences ? 0 : 1, twoReferences ? 2 : 1),
      ],
    ),
  );
}
