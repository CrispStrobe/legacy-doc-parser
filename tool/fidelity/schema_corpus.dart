// SPDX-License-Identifier: MPL-2.0
// No native Office application is needed to generate this schema corpus.
import 'dart:convert';
import 'dart:io';

import 'package:legacy_doc_parser/legacy_doc_parser.dart';

import 'metafile_probe.dart' as metafiles;
import 'review_schema_fixture.dart' as reviews;
import 'section_review_fixture.dart' as sections;
import 'shape_probe.dart' as shapes;
import 'table_borders_fixture.dart' as table_borders;
import 'table_layout_fixture.dart' as table_layout;
import 'table_origin_fixture.dart' as origins;
import 'table_text_fixture.dart' as table_text;

void main(List<String> arguments) {
  if (arguments.length != 1) {
    throw ArgumentError(
      'Usage: dart run tool/fidelity/schema_corpus.dart NEW_DIR',
    );
  }
  final root = Directory(arguments.single).absolute;
  if (root.existsSync()) throw ArgumentError('Output already exists.');
  root.createSync(recursive: true);
  final manifest = <Map<String, Object>>[];
  void record(String name, String source, String output, String producer) {
    if (!File('${root.path}/$source').existsSync() ||
        !File('${root.path}/$output').existsSync()) {
      throw StateError('The schema corpus is missing the required case $name.');
    }
    manifest.add({
      'name': name,
      'source': source,
      'output': output,
      'producer': producer,
    });
  }

  origins.main(['${root.path}/table-origin']);
  for (final name in [
    'default',
    'zero-margin',
    'wide-margin',
    'negative-origin',
    'positive-origin',
    'independent-gap',
    'cell-margin',
    'nested',
    'nested-wide',
  ]) {
    record(
      'table-origin/$name',
      'table-origin/$name.doc',
      'table-origin/$name-converted.docx',
      'tool/fidelity/table_origin_fixture.dart',
    );
  }
  table_text.main(['${root.path}/table-text']);
  for (final name in ['table-text-conditions', 'table-text-relative-toggles']) {
    record(
      name,
      'table-text/$name.doc',
      'table-text/$name.docx',
      'tool/fidelity/table_text_fixture.dart',
    );
  }
  table_layout.main(['${root.path}/table-layout']);
  for (final name in [
    'auto',
    'minimum-short',
    'minimum-content',
    'exact-short',
    'exact-content',
    'keep-row',
    'split-row',
    'cell-layout',
  ]) {
    record(
      'table-layout/$name',
      'table-layout/$name.doc',
      'table-layout/$name-converted.docx',
      'tool/fidelity/table_layout_fixture.dart',
    );
  }
  table_borders.main(['${root.path}/table-borders']);
  for (final name in [
    'old-after',
    'old-before',
    'old-nil',
    'old-explicit',
    'modern-after',
    'modern-before',
    'modern-nil',
    'modern-explicit',
    'range-nil',
    'range-none',
    'interior-colors',
    'row-reset',
  ]) {
    record(
      'table-borders/$name',
      'table-borders/$name.doc',
      'table-borders/$name-converted.docx',
      'tool/fidelity/table_borders_fixture.dart',
    );
  }
  shapes.main(['${root.path}/shapes']);
  for (final name in [
    'rect',
    'ellipse',
    'line',
    'custom',
    for (final axis in ['h', 'v'])
      for (final flip in ['none', 'x', 'y', 'xy']) 'line-$axis-$flip',
  ]) {
    record(
      'shapes/$name',
      'shapes/$name.doc',
      'shapes/$name.docx',
      'tool/fidelity/shape_probe.dart',
    );
  }
  metafiles.main(['${root.path}/metafiles']);
  for (final format in ['emf32', 'emf16', 'wmf']) {
    for (final mode in ['alternate', 'winding']) {
      final name = '$format-$mode';
      record(
        'metafiles/$name',
        'metafiles/$name.doc',
        'metafiles/$name.docx',
        'tool/fidelity/metafile_probe.dart',
      );
    }
  }
  reviews.main(['${root.path}/reviews']);
  for (final name in [
    'numbering-change',
    'numbering-insertion',
    'listnum-display-change',
  ]) {
    record(
      'reviews/$name',
      'reviews/$name.doc',
      'reviews/$name.docx',
      'tool/fidelity/review_schema_fixture.dart',
    );
  }
  sections.main(['${root.path}/section-review.doc']);
  File('${root.path}/section-review.docx').writeAsBytesSync(
    convertLegacyWordToStructuredDocx(
      File('${root.path}/section-review.doc').readAsBytesSync(),
    ).bytes,
  );
  record(
    'section-review',
    'section-review.doc',
    'section-review.docx',
    'tool/fidelity/section_review_fixture.dart',
  );
  final repository = File.fromUri(Platform.script).parent.parent.parent;
  Directory('${root.path}/native-inputs').createSync();
  for (final name in ['formatting', 'linked-textboxes']) {
    final source = File(
      '${repository.path}/test/fixtures/word_native/$name.doc',
    );
    source.copySync('${root.path}/native-inputs/$name.doc');
    File('${root.path}/native-inputs/$name.docx').writeAsBytesSync(
      convertLegacyWordToStructuredDocx(source.readAsBytesSync()).bytes,
    );
    record(
      'native-inputs/$name',
      'native-inputs/$name.doc',
      'native-inputs/$name.docx',
      'test/fixtures/word_native/$name.doc',
    );
  }
  final outputs = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.docx'))
      .map((file) => file.path.substring(root.path.length + 1))
      .toSet();
  final expected = manifest.map((entry) => entry['output'] as String).toSet();
  if (outputs.length != manifest.length ||
      outputs.length != expected.length ||
      !outputs.containsAll(expected)) {
    throw StateError('The schema corpus has unexpected or duplicate outputs.');
  }
  File('${root.path}/manifest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'version': 1, 'cases': manifest})}\n',
  );
  stdout.writeln('Generated ${manifest.length} deterministic schema cases.');
}
