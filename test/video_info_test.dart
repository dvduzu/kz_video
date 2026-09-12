import 'package:flutter_test/flutter_test.dart';
import 'package:kz_video/data/models.dart';

void main() {
  test('VideoInfo fromJson/toJson round trip keeps aid', () {
    final json = <String, dynamic>{
      'bvid': 'BV1xx411c7mD',
      'title': 't',
      'pic': 'https://example.com/p.jpg',
      'duration': 123,
      'owner': 'up',
      'view': 456,
      'pubdate': 1700000000,
      'mid': 7,
      'tid': 100,
      'aid': 888,
    };
    final v = VideoInfo.fromJson(json);
    expect(v.bvid, 'BV1xx411c7mD');
    expect(v.aid, 888);
    expect(v.mid, 7);
    final back = VideoInfo.fromJson(v.toJson());
    expect(back.bvid, v.bvid);
    expect(back.duration, v.duration);
    expect(back.aid, v.aid);
  });

  test('optional fields default to zero', () {
    final v = VideoInfo.fromJson({'bvid': 'b', 'title': 't', 'pic': 'p', 'duration': 1, 'owner': 'o', 'view': 2});
    expect(v.pubdate, 0);
    expect(v.mid, 0);
    expect(v.tid, 0);
    expect(v.aid, 0);
  });
}
