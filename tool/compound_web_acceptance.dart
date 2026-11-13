// SPDX-License-Identifier: MPL-2.0
// Executed by tool/verify_web.py in actual compiled JavaScript.

import 'dart:typed_data';

import 'package:legacy_doc_parser/src/bounded_cfb_reader.dart';
import 'package:legacy_doc_parser/src/compound/byte_source.dart';
import 'package:legacy_doc_parser/src/compound/cfbf_reader.dart';
import 'package:legacy_doc_parser/src/compound/cfbf_writer.dart';

import '../test/support/compound_allocation_fixture.dart';
import '../test/support/compound_size_fixture.dart';

Map<String, Object?> verifyCompoundAllocationWebCases() {
  var rejections = 0;
  void rejects(void Function() read, String label) {
    try {
      read();
    } on CfbfException {
      rejections++;
      return;
    } on FormatException {
      rejections++;
      return;
    }
    throw StateError('Accepted malformed compound allocation: $label');
  }

  for (final mutation in [
    'duplicate-fat',
    'fat-count-zero',
    'fat-count-extra',
    'difat-count-extra',
    'minifat-count-extra',
    'minifat-free-terminal',
    'directory-count',
    'directory-free-terminal',
  ]) {
    final bytes = compoundAllocationFixture(mutation);
    final before = Uint8List.fromList(bytes);
    rejects(() => CfbfFile.fromBytes(bytes), 'raw $mutation');
    rejects(() => BoundedCfbReader(bytes), 'bounded $mutation');
    _equal(bytes, before, 'source $mutation');
  }
  for (final (mutation, path) in [
    ('mini-cycle-tail', 'Small'),
    ('mini-free-tail', 'Small'),
    ('regular-cycle-tail', 'Large'),
    ('regular-free-tail', 'Large'),
    ('root-cycle-tail', 'Small'),
    ('mini-cycle-spare', 'Small'),
    ('regular-cycle-spare', 'Large'),
  ]) {
    final bytes = compoundAllocationFixture(mutation);
    final before = Uint8List.fromList(bytes);
    rejects(() => CfbfFile.fromBytes(bytes).readPath(path), 'raw $mutation');
    rejects(() => BoundedCfbReader(bytes).readPath(path), 'bounded $mutation');
    _equal(bytes, before, 'source $mutation');
  }

  var streamComparisons = 0;
  void valid(Uint8List bytes, Map<String, List<int>> streams) {
    final before = Uint8List.fromList(bytes);
    final raw = CfbfFile.fromBytes(bytes), bounded = BoundedCfbReader(bytes);
    for (final stream in streams.entries) {
      _equal(raw.readPath(stream.key)!, stream.value, 'raw ${stream.key}');
      _equal(
        bounded.readPath(stream.key)!,
        stream.value,
        'bounded ${stream.key}',
      );
      streamComparisons += 2;
    }
    _equal(bytes, before, 'valid source');
  }

  valid(compoundAllocationFixture('valid'), {
    'Small': List.generate(65, (index) => index),
    'Large': List.generate(4097, (index) => index % 251),
  });
  valid(compoundAllocationFixture('spare-capacity'), {
    'Small': [0],
    'Large': List.generate(4096, (index) => index % 251),
  });
  valid(compoundSizeFixture(version4: true), {
    'Large': List.generate(4096, (index) => index & 255),
  });
  final large = List.generate(8 * 1024 * 1024, (index) => index % 251);
  final writer = CfbfWriter()..addStream('Large', large);
  for (var index = 0; index < 130; index++) {
    writer.addStream('Small$index', [index & 255]);
  }
  valid(writer.build(), {
    'Large': large,
    'Small129': [129],
  });
  for (final size in [1, 65, 127]) {
    valid(compoundPartialMiniFixture(size), {
      'Small': List.generate(size, (index) => index & 255),
    });
  }
  final shared = compoundSharedChainFixture();
  final counted = _CountedSource(shared);
  final raw = CfbfFile.open(counted), bounded = BoundedCfbReader(shared);
  final expected = List.generate(4096, (index) => index % 251);
  counted.views = counted.zeroLengthViews = 0;
  for (final entry in raw.entries.where((entry) => entry.isStream)) {
    _equal(raw.readEntry(entry), expected, 'raw shared tail');
    _equal(bounded.readPath(entry.name)!, expected, 'bounded shared tail');
  }
  if (counted.views != 520 || counted.zeroLengthViews != 0) {
    throw StateError('Shared tails repeated spare-payload reads');
  }
  return {
    'malformedCases': 15,
    'readerRejections': rejections,
    'validCases': 7,
    'streamComparisons': streamComparisons,
    'sharedTailStreams': 65,
    'sharedTailSectorReads': counted.views,
    'sharedTailZeroLengthReads': counted.zeroLengthViews,
    'sourceUnchanged': true,
  };
}

class _CountedSource extends MemoryByteSource {
  _CountedSource(super.bytes);

  var views = 0;
  var zeroLengthViews = 0;

  @override
  Uint8List view(int offset, int length) {
    views++;
    if (length == 0) zeroLengthViews++;
    return super.view(offset, length);
  }
}

void _equal(List<int> actual, List<int> expected, String label) {
  if (actual.length != expected.length) {
    throw StateError('$label length mismatch');
  }
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) {
      throw StateError('$label byte mismatch at $index');
    }
  }
}
