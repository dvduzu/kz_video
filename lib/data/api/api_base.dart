import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import '../bilibili_client.dart';

class ApiBase {
  final BilibiliClient client;
  final Dio dio;
  ApiBase(this.client) : dio = client.dio;

  Future<Map<String, dynamic>> wbiGet(String path, Map<String, dynamic> params) => client.wbiGet(path, params);

  Map<String, dynamic> dmImgParams() {
    const vendors = ['AMD', 'Intel', 'NVIDIA'];
    const gpus = ['AMD Radeon RX 6700 XT', 'AMD Radeon RX 6600', 'Intel(R) UHD Graphics 630', 'Intel(R) Iris(R) Xe Graphics', 'NVIDIA GeForce RTX 3060', 'NVIDIA GeForce RTX 4060 Laptop GPU', 'NVIDIA GeForce GTX 1650 Ti'];
    final r = Random();
    final vendor = vendors[r.nextInt(vendors.length)];
    final gpu = gpus[r.nextInt(gpus.length)];
    final webgl = 'WebGL 1.0 (OpenGL ES 2.0 Chromium)';
    final angle = 'ANGLE ($vendor, $gpu Direct3D11 vs_5_0 ps_5_0, D3D11)Google Inc. ($vendor)';
    final w = 1920 - 60 - r.nextInt(60);
    final h = 1080 - 90 - r.nextInt(60);
    final rnd = r.nextInt(114);
    final o1 = 3 * r.nextInt(514);
    final o2 = 4 * r.nextInt(514);
    String b64(String s) => base64Encode(utf8.encode(s)).replaceAll('=', '');
    return {
      'dm_img_list': '[]',
      'dm_img_str': b64(webgl),
      'dm_cover_img_str': b64(angle),
      'dm_img_inter': '{"ds":[],"wh":[$w,$h,$rnd],"of":[$o1,$o2,$rnd]}',
    };
  }
}
