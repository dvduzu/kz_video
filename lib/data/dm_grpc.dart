import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import '../core/logger.dart';
import 'bilibili_constants.dart';
import 'danmaku_parser.dart';
import 'models.dart';

class DmGrpc {
  final Dio dio;

  DmGrpc(this.dio);

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://app.bilibili.com',
      headers: {
        'User-Agent': BiliConstants.appUserAgent,
      },
    ));
    dio.httpClientAdapter = Http2Adapter(ConnectionManager(idleTimeout: const Duration(seconds: 15)));
    return dio;
  }

  Uint8List _encodeReq(int cid, int segmentIndex) {
    final b = BytesBuilder();
    void vint(int v) {
      var x = v;
      while (x >= 0x80) {
        b.addByte((x & 0x7f) | 0x80);
        x >>= 7;
      }
      b.addByte(x);
    }
    void field(int num, int wire) => vint((num << 3) | wire);
    field(2, 0);
    vint(cid);
    field(3, 0);
    vint(1);
    field(4, 0);
    vint(segmentIndex);
    return b.toBytes();
  }

  Future<List<DanmakuItem>> segMobile(int cid, int segmentIndex, {Map<String, String> headers = const {}}) async {
    final payload = _encodeReq(cid, segmentIndex);
    final frame = Uint8List(5 + payload.length)
      ..[0] = 0
      ..buffer.asByteData(1, 4).setInt32(0, payload.length, Endian.big)
      ..setAll(5, payload);
    final resp = await dio.post<List<int>>(
      '/bilibili.community.service.dm.v1.DM/DmSegMobile',
      data: frame,
      options: Options(
        contentType: 'application/grpc',
        responseType: ResponseType.bytes,
        headers: headers,
      ),
    );
    final status = resp.headers.value('Grpc-Status');
    if (status != '0') {
      KzvLogger.debug('dm grpc seg=$segmentIndex status=$status');
      return [];
    }
    final data = Uint8List.fromList(resp.data ?? const []);
    if (data.length < 5) return [];
    final len = ByteData.sublistView(data, 1, 5).getInt32(0, Endian.big);
    if (5 + len > data.length) return [];
    var body = data.sublist(5, 5 + len);
    if (data[0] == 1) {
      body = Uint8List.fromList(gzip.decode(body));
    }
    return DanmakuParser.parse(body);
  }
}
