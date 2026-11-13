// SPDX-License-Identifier: MPL-2.0
// Independently authored source controls. Never edits a source file in place.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:legacy_doc_parser/src/bounded_cfb_reader.dart';
import 'package:legacy_doc_parser/src/compound/cfbf_writer.dart';

int _u16(Uint8List bytes, int at) =>
    ByteData.sublistView(bytes).getUint16(at, Endian.little);
int _u32(Uint8List bytes, int at) =>
    ByteData.sublistView(bytes).getUint32(at, Endian.little);

Uint8List _record(int header, int type, List<int> payload) {
  final bytes = Uint8List(8 + payload.length);
  final data = ByteData.sublistView(bytes);
  data.setUint16(0, header, Endian.little);
  data.setUint16(2, type, Endian.little);
  data.setUint32(4, payload.length, Endian.little);
  bytes.setRange(8, bytes.length, payload);
  return bytes;
}

List<Uint8List> _children(Uint8List bytes) {
  final result = <Uint8List>[];
  var at = 8;
  while (at < bytes.length) {
    if (at + 8 > bytes.length) throw StateError('Truncated record header.');
    final end = at + 8 + _u32(bytes, at + 4);
    if (end > bytes.length || result.length >= 20000) {
      throw StateError('Invalid or excessive record extent.');
    }
    result.add(Uint8List.sublistView(bytes, at, end));
    at = end;
  }
  return result;
}

Uint8List _propertyRecord(Map<int, int?> values) {
  final active = values.entries.where((entry) => entry.value != null).toList()
    ..sort((a, b) => (a.key & 0x3fff).compareTo(b.key & 0x3fff));
  final bytes = Uint8List(active.length * 6);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < active.length; index++) {
    data.setUint16(index * 6, active[index].key, Endian.little);
    data.setUint32(index * 6 + 2, active[index].value!, Endian.little);
  }
  return _record((active.length << 4) | 3, 0xf00b, bytes);
}

void main(List<String> arguments) {
  if (arguments.length != 3) {
    throw ArgumentError('SOURCE.doc OUTPUT.doc PROPERTIES.json');
  }
  final inputPath = File(arguments[0]), outputPath = File(arguments[1]);
  if (outputPath.existsSync()) throw StateError('Output already exists.');
  final changes = <int, int?>{};
  for (final entry
      in (jsonDecode(File(arguments[2]).readAsStringSync()) as Map).entries) {
    final key = int.parse(entry.key as String, radix: 16);
    if (key < 0 || key > 0x7fff || changes.containsKey(key & 0x3fff)) {
      throw StateError('Invalid or duplicate requested source property.');
    }
    final value = entry.value as int?;
    if (value != null && (value < -0x80000000 || value > 0xffffffff)) {
      throw StateError('Source property does not fit 32 bits.');
    }
    changes[key] = value;
  }
  final changedIds = changes.keys.map((key) => key & 0x3fff).toSet();
  if (changedIds.length != changes.length || changes.isEmpty) {
    throw StateError('Source property identifiers are not distinct.');
  }
  final source = BoundedCfbReader(inputPath.readAsBytesSync());
  final word = Uint8List.fromList(source.readPath('WordDocument')!);
  final wordData = ByteData.sublistView(word);
  if (_u16(word, 0) != 0xa5ec || _u16(word, 152) < 51) {
    throw StateError('Control requires a Word 97+ FIB with OfficeArt.');
  }
  final tableName = (_u16(word, 10) & 0x200) == 0 ? '0Table' : '1Table';
  final table = source.readPath(tableName)!;
  const pair = 154 + 50 * 8;
  final offset = _u32(word, pair), length = _u32(word, pair + 4);
  if (length < 8 || offset + length > table.length) {
    throw StateError('Invalid source OfficeArt extent.');
  }
  final art = Uint8List.sublistView(table, offset, offset + length);
  final edits = <Map<String, Object?>>[];
  var targetCount = 0;
  Uint8List rewrite(Uint8List record, int depth) {
    if (depth > 64 || record.length != 8 + _u32(record, 4)) {
      throw StateError('Invalid source record.');
    }
    final header = _u16(record, 0), type = _u16(record, 2);
    if ((header & 15) != 15) return record;
    var children = _children(record);
    final target =
        type == 0xf004 &&
        children.any(
          (child) => _u16(child, 2) == 0xf00a && (_u16(child, 0) >> 4) == 202,
        );
    if (target) {
      targetCount++;
      final filtered = <Uint8List>[];
      var inserted = false;
      for (final child in children) {
        final childType = _u16(child, 2);
        if (!const {0xf00b, 0xf121, 0xf122}.contains(childType)) {
          filtered.add(child);
          continue;
        }
        final count = _u16(child, 0) >> 4;
        var extra = 8 + count * 6;
        if (extra > child.length) throw StateError('Truncated source FOPT.');
        final entries = <(int, int, Uint8List)>[];
        for (var index = 0; index < count; index++) {
          final at = 8 + index * 6;
          final opid = _u16(child, at), value = _u32(child, at + 2);
          final size = (opid & 0x8000) == 0 ? 0 : value;
          if (extra + size > child.length) {
            throw StateError('Unsupported source complex FOPT extent.');
          }
          if (changedIds.contains(opid & 0x3fff)) {
            edits.add({
              'property': opid,
              'oldValue': value,
              'complexBytes': size,
            });
          } else {
            entries.add((
              opid,
              value,
              Uint8List.sublistView(child, extra, extra + size),
            ));
          }
          extra += size;
        }
        if (extra != child.length) {
          throw StateError('Unexpected source FOPT bytes.');
        }
        if (childType == 0xf00b && !inserted) {
          for (final entry in changes.entries) {
            if (entry.value != null) {
              entries.add((entry.key, entry.value!, Uint8List(0)));
            }
          }
          inserted = true;
        }
        entries.sort((a, b) => (a.$1 & 0x3fff).compareTo(b.$1 & 0x3fff));
        final fixed = Uint8List(entries.length * 6);
        final fixedData = ByteData.sublistView(fixed);
        for (var index = 0; index < entries.length; index++) {
          fixedData.setUint16(index * 6, entries[index].$1, Endian.little);
          fixedData.setUint32(index * 6 + 2, entries[index].$2, Endian.little);
        }
        filtered.add(
          _record((entries.length << 4) | (_u16(child, 0) & 15), childType, [
            ...fixed,
            for (final entry in entries) ...entry.$3,
          ]),
        );
      }
      if (!inserted) filtered.add(_propertyRecord(changes));
      children = filtered;
    }
    return _record(header, type, [
      for (final child in children) ...rewrite(child, depth + 1),
    ]);
  }

  var cursor = 8 + _u32(art, 4);
  if (_u16(art, 2) != 0xf000 || cursor > art.length) {
    throw StateError('Control requires a bounded OfficeArt drawing group.');
  }
  // A removed property must not remain inherited from drawing defaults.
  for (final child in _children(Uint8List.sublistView(art, 0, cursor))) {
    if (!const {0xf00b, 0xf121, 0xf122}.contains(_u16(child, 2))) continue;
    final count = _u16(child, 0) >> 4;
    for (var index = 0; index < count; index++) {
      final id = _u16(child, 8 + index * 6) & 0x3fff;
      if (changedIds.contains(id) &&
          changes.entries.any(
            (entry) => (entry.key & 0x3fff) == id && entry.value == null,
          )) {
        throw StateError('Removed source property remains inherited.');
      }
    }
  }
  final rewritten = <int>[...art.sublist(0, cursor)];
  while (cursor < art.length) {
    final label = art[cursor++];
    if (label > 1 || cursor + 8 > art.length) {
      throw StateError('Invalid drawing story prefix.');
    }
    final end = cursor + 8 + _u32(art, cursor + 4);
    if (end > art.length) throw StateError('Invalid drawing story extent.');
    rewritten.add(label);
    rewritten.addAll(rewrite(Uint8List.sublistView(art, cursor, end), 0));
    cursor = end;
  }
  if (targetCount != 1) {
    throw StateError('Control requires exactly one textbox.');
  }
  final newTable = Uint8List.fromList([...table, ...rewritten]);
  wordData.setUint32(pair, table.length, Endian.little);
  wordData.setUint32(pair + 4, rewritten.length, Endian.little);
  final root = source.root;
  final writer = CfbfWriter(
    clsid: root.clsid,
    stateBits: root.stateBits,
    createdFiletime: root.createdFiletime,
    modifiedFiletime: root.modifiedFiletime,
  );
  void copy(CfbfDirectoryEntry parent, String prefix) {
    for (final entry in source.childrenOf(parent)) {
      final path = prefix.isEmpty ? entry.name : '$prefix/${entry.name}';
      if (entry.isStorage) {
        writer.addStorage(
          path,
          clsid: entry.clsid,
          stateBits: entry.stateBits,
          createdFiletime: entry.createdFiletime,
          modifiedFiletime: entry.modifiedFiletime,
        );
        copy(entry, path);
      } else {
        writer.addStream(
          path,
          path == 'WordDocument'
              ? word
              : path == tableName
              ? newTable
              : source.readEntry(entry),
          clsid: entry.clsid,
          stateBits: entry.stateBits,
          createdFiletime: entry.createdFiletime,
          modifiedFiletime: entry.modifiedFiletime,
        );
      }
    }
  }

  copy(root, '');
  outputPath.writeAsBytesSync(writer.build());
  stdout.writeln(
    jsonEncode({
      'control': 'single-textbox-fopt-properties',
      'input': inputPath.path,
      'output': outputPath.path,
      'tableStream': tableName,
      'priorOfficeArt': {'offset': offset, 'length': length},
      'newOfficeArt': {'offset': table.length, 'length': rewritten.length},
      'removedOperands': edits,
      'requestedProperties': {
        for (final entry in changes.entries)
          entry.key.toRadixString(16): entry.value,
      },
      'sourceCoordinatesChanged': false,
    }),
  );
}
