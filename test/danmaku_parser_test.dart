import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_video/data/danmaku_parser.dart';

List<int> _varint(int v) {
  final out = <int>[];
  var x = v;
  while (x >= 0x80) {
    out.add((x & 0x7f) | 0x80);
    x >>= 7;
  }
  out.add(x);
  return out;
}

List<int> _tag(int field, int wire) => _varint((field << 3) | wire);

List<int> _lenDelim(int field, List<int> payload) => [..._tag(field, 2), ..._varint(payload.length), ...payload];

void main() {
  test('parses a danmaku element from protobuf bytes', () {
    final elem = <int>[
      ..._lenDelim(7, utf8.encode('hello')),
      ..._tag(2, 0), ..._varint(1500),
      ..._tag(3, 0), ..._varint(1),
      ..._tag(5, 0), ..._varint(0xFFFFFF),
    ];
    final items = DanmakuParser.parse(_lenDelim(1, elem));
    expect(items, hasLength(1));
    expect(items.first.text, 'hello');
    expect(items.first.time, closeTo(1.5, 1e-9));
    expect(items.first.mode, 1);
    expect(items.first.color, 0xFFFFFF);
  });

  test('returns empty for empty input', () {
    expect(DanmakuParser.parse(const []), isEmpty);
  });

  test('defaults color and mode when absent', () {
    final items = DanmakuParser.parse(_lenDelim(1, _lenDelim(7, utf8.encode('x'))));
    expect(items, hasLength(1));
    expect(items.first.mode, 1);
    expect(items.first.color, 0xFFFFFF);
    expect(items.first.time, 0);
  });
}
