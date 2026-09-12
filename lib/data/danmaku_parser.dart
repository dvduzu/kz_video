import 'dart:convert';
import 'models.dart';

abstract final class DanmakuParser {
  static List<DanmakuItem> parse(List<int> bytes) {
    final list = <DanmakuItem>[];
    var i = 0;
    while (i < bytes.length) {
      final tag = _readVarint(bytes, i);
      i = tag.$2;
      final field = tag.$1 >> 3;
      final wire = tag.$1 & 7;
      if (wire == 2) {
        final len = _readVarint(bytes, i);
        i = len.$2;
        final end = i + len.$1;
        if (end > bytes.length) break;
        if (field == 1) list.add(_parseElem(bytes.sublist(i, end)));
        i = end;
      } else if (wire == 0) {
        i = _readVarint(bytes, i).$2;
      } else if (wire == 5) {
        i += 4;
      } else if (wire == 1) {
        i += 8;
      } else {
        break;
      }
    }
    return list;
  }

  static DanmakuItem _parseElem(List<int> b) {
    var progress = 0;
    var mode = 1;
    var color = 0xFFFFFF;
    var content = '';
    var i = 0;
    while (i < b.length) {
      final tag = _readVarint(b, i);
      i = tag.$2;
      final field = tag.$1 >> 3;
      final wire = tag.$1 & 7;
      if (wire == 2) {
        final len = _readVarint(b, i);
        i = len.$2;
        final end = i + len.$1;
        if (end > b.length) break;
        if (field == 7) content = utf8.decode(b.sublist(i, end), allowMalformed: true);
        i = end;
      } else if (wire == 0) {
        final v = _readVarint(b, i);
        i = v.$2;
        if (field == 2) {
          progress = v.$1;
        } else if (field == 3) {
          mode = v.$1;
        } else if (field == 5) {
          color = v.$1;
        }
      } else if (wire == 5) {
        i += 4;
      } else if (wire == 1) {
        i += 8;
      } else {
        break;
      }
    }
    return DanmakuItem(progress / 1000.0, mode, color, content);
  }

  static (int, int) _readVarint(List<int> b, int i) {
    var result = 0;
    var shift = 0;
    while (i < b.length) {
      final byte = b[i++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
    }
    return (result, i);
  }
}
