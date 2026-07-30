import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:image/image.dart' as img;

/// 图片编解码服务，所有耗时操作均在 isolate 中执行。
class ImageCodecService {
  ImageCodecService._();
  static final ImageCodecService _instance = ImageCodecService._();
  factory ImageCodecService() => _instance;

  /// 直接读取文件原始字节，不做任何解码。
  Future<Uint8List> readBytes(String path) async {
    return File(path).readAsBytes();
  }

  /// 在 isolate 中解码图片并重新编码为 PNG 字节。
  ///
  /// 用于 JPEG 等格式，避免 Flutter 在 UI 线程上执行慢速的 JPEG 解码。
  /// 解码后的 PNG 字节由 Flutter 引擎的 C++ PNG 解码器快速处理。
  Future<Uint8List> decodeToPng(String path) async {
    final bytes = await File(path).readAsBytes();
    return bytesToPng(bytes);
  }

  /// 将已读入内存的图片字节解码后重编码为 PNG。
  Future<Uint8List> bytesToPng(Uint8List bytes) async {
    return Isolate.run(() {
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');
      return Uint8List.fromList(img.encodePng(image));
    });
  }
}
