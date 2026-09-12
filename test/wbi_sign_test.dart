import 'package:flutter_test/flutter_test.dart';
import 'package:kz_video/data/wbi_sign.dart';

const _tab = <int>[
  46,47,18,2,53,8,23,32,15,50,10,31,58,3,45,35,27,43,5,49,
  33,9,42,19,29,28,14,39,12,38,41,13,37,48,7,16,24,55,40,
  61,26,17,0,1,60,51,30,4,22,25,54,21,56,59,6,63,57,62,11,
  36,20,34,44,52,
];

void main() {
  test('getMixinKey reorders characters by the mixin table', () {
    final orig = List.generate(64, (i) => String.fromCharCode(65 + i)).join();
    final expected = _tab.map((i) => orig[i]).join();
    expect(WbiSign.getMixinKey(orig), expected);
  });

  test('sign adds wts and a 32-char w_rid', () {
    final params = <String, dynamic>{'mid': 1, 'platform': 'web'};
    WbiSign.sign(params, 'abcdefghijklmnopqrstuvwxyz123456');
    expect(params.containsKey('wts'), isTrue);
    expect(params['wts'], isA<int>());
    expect((params['w_rid'] as String).length, 32);
  });
}
