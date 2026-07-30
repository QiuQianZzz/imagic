import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../services/file_service.dart';
import '../../../services/image_codec_service.dart';

/// 图片查看状态管理，负责图片加载、导航和错误处理。
class ViewerState extends ChangeNotifier {
  final ImageCodecService _codec = ImageCodecService();
  final FileService _fileService = FileService();

  Uint8List? _imageBytes;
  Uint8List? _svgBytes;
  String? _currentPath;
  List<String> _files = [];
  int _currentIndex = -1;
  String? _errorMessage;
  bool _isSvg = false;
  int _imageWidth = 0;
  int _imageHeight = 0;
  int _fileSize = 0;

  Uint8List? get imageBytes => _imageBytes;
  Uint8List? get svgBytes => _svgBytes;
  String? get currentPath => _currentPath;
  List<String> get files => _files;
  int get currentIndex => _currentIndex;
  bool get hasImage => _imageBytes != null || _isSvg;
  bool get isSvg => _isSvg;
  String? get errorMessage => _errorMessage;
  int get imageWidth => _imageWidth;
  int get imageHeight => _imageHeight;
  int get fileSize => _fileSize;

  String get currentName {
    if (_currentPath == null) return '';
    return _currentPath!.split(Platform.pathSeparator).last;
  }

  int get totalCount => _files.length;

  /// 打开指定路径的图片文件。
  ///
  /// 根据文件类型采用不同的加载策略：
  /// - SVG：直接读取原始字节
  /// - PNG：直接读取原始字节，由 Flutter 引擎的 C++ PNG 解码器快速处理
  /// - 其他（JPEG 等）：在 isolate 中解码并重编码为 PNG，避免 UI 线程慢速解码
  Future<void> openFile(String path) async {
    try {
      _errorMessage = null;
      _isSvg = p.extension(path).toLowerCase() == '.svg';

      if (_isSvg) {
        _svgBytes = await _codec.readBytes(path);
        _imageBytes = null;
        _readSvgDimensions(_svgBytes!);
      } else {
        _imageWidth = 0;
        _imageHeight = 0;
        final bytes = await _codec.readBytes(path);
        _imageBytes = bytes;
        if (bytes.length >= 8 &&
            bytes[0] == 0x89 && bytes[1] == 0x50 &&
            bytes[2] == 0x4E && bytes[3] == 0x47 &&
            bytes[4] == 0x0D && bytes[5] == 0x0A &&
            bytes[6] == 0x1A && bytes[7] == 0x0A) {
          _readPngDimensions(bytes);
        } else if (bytes.length >= 2 &&
            bytes[0] == 0xFF && bytes[1] == 0xD8) {
          _readJpegDimensions(bytes);
        } else if (bytes.length >= 12 &&
            bytes[0] == 0x52 && bytes[1] == 0x49 &&
            bytes[2] == 0x46 && bytes[3] == 0x46 &&
            bytes[8] == 0x57 && bytes[9] == 0x45 &&
            bytes[10] == 0x42 && bytes[11] == 0x50) {
          _readWebpDimensions(bytes);
        }
        _svgBytes = null;
      }

      _currentPath = path;
      _loadAdjacentFiles(path);
      _fileSize = await File(path).length();

      notifyListeners();
    } catch (e) {
      _errorMessage = '打开文件失败: $e';
      notifyListeners();
    }
  }

  /// 从 PNG 字节中读取 IHDR 块获取图片宽高。
  /// 先校验 PNG 签名（8字节），宽高位 IHDR 块中偏移 16/20，各 4 字节大端。
  void _readPngDimensions(Uint8List bytes) {
    if (bytes.length < 24) return;
    if (bytes.length < 8 ||
        bytes[0] != 0x89 || bytes[1] != 0x50 ||
        bytes[2] != 0x4E || bytes[3] != 0x47 ||
        bytes[4] != 0x0D || bytes[5] != 0x0A ||
        bytes[6] != 0x1A || bytes[7] != 0x0A) {
      return;
    }
    final offset = bytes.offsetInBytes;
    final w = ByteData.view(bytes.buffer, offset + 16, 4).getUint32(0);
    final h = ByteData.view(bytes.buffer, offset + 20, 4).getUint32(0);
    _imageWidth = w;
    _imageHeight = h;
  }

  /// 从 JPEG 字节中扫描 SOF 段读取图片宽高。
  void _readJpegDimensions(Uint8List bytes) {
    final buf = bytes.buffer;
    final off = bytes.offsetInBytes;
    int i = 2;
    while (i < bytes.length - 1) {
      if (bytes[i] != 0xFF) { i += 1; continue; }
      final marker = bytes[i + 1];
      if (marker == 0xD9 || marker == 0xDA) return;
      if (marker >= 0xD0 && marker <= 0xD7) { i += 2; continue; }
      if (marker == 0x00 || marker == 0xFF) { i += 1; continue; }
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        if (i + 10 >= bytes.length) return;
        _imageWidth = ByteData.view(buf, off + i + 7, 2).getUint16(0);
        _imageHeight = ByteData.view(buf, off + i + 5, 2).getUint16(0);
        return;
      }
      if (i + 4 >= bytes.length) return;
      final segLen = ByteData.view(buf, off + i + 2, 2).getUint16(0);
      if (segLen < 2) return;
      i += 2 + segLen;
    }
  }

  /// 遍历 RIFF 块找到 VP8/VP8L/VP8X 并读取宽高。
  void _readWebpDimensions(Uint8List bytes) {
    final buf = bytes.buffer;
    final off = bytes.offsetInBytes;
    int pos = 12;
    while (pos + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final chunkSize = ByteData.view(buf, off + pos + 4, 4).getUint32(0, Endian.little);
      final d = pos + 8;
      if (chunkId == 'VP8 ' && d + 8 <= bytes.length) {
        _imageWidth = (ByteData.view(buf, off + d + 4, 2).getUint16(0, Endian.little) & 0x3FFF) + 1;
        _imageHeight = (ByteData.view(buf, off + d + 6, 2).getUint16(0, Endian.little) & 0x3FFF) + 1;
        return;
      }
      if (chunkId == 'VP8L' && d + 5 <= bytes.length) {
        final packed = ByteData.view(buf, off + d + 1, 4).getUint32(0, Endian.little);
        _imageWidth = (packed & 0x3FFF) + 1;
        _imageHeight = ((packed >> 14) & 0x3FFF) + 1;
        return;
      }
      if (chunkId == 'VP8X' && d + 10 <= bytes.length) {
        _imageWidth = (bytes[d + 4] | (bytes[d + 5] << 8) | (bytes[d + 6] << 16)) + 1;
        _imageHeight = (bytes[d + 7] | (bytes[d + 8] << 8) | (bytes[d + 9] << 16)) + 1;
        return;
      }
      pos += 8 + chunkSize;
      if (chunkSize.isOdd) pos++;
    }
  }

  /// 从 SVG 字节中解析 viewBox 或 width/height 属性获取宽高。
  void _readSvgDimensions(Uint8List bytes) {
    try {
      final xml = String.fromCharCodes(bytes);
      final vb = RegExp(r'viewBox\s*=\s*"([^"]*)"', caseSensitive: false).firstMatch(xml);
      if (vb != null) {
        final parts = vb.group(1)!.trim().split(RegExp(r'\s+'));
        if (parts.length == 4) {
          _imageWidth = double.tryParse(parts[2])?.toInt() ?? 0;
          _imageHeight = double.tryParse(parts[3])?.toInt() ?? 0;
          return;
        }
      }
      final w = RegExp(r'width\s*=\s*"([^"]*)"', caseSensitive: false).firstMatch(xml);
      final h = RegExp(r'height\s*=\s*"([^"]*)"', caseSensitive: false).firstMatch(xml);
      if (w != null && h != null) {
        final ws = w.group(1)!.replaceAll(RegExp(r'[^0-9.]'), '');
        final hs = h.group(1)!.replaceAll(RegExp(r'[^0-9.]'), '');
        _imageWidth = double.tryParse(ws)?.toInt() ?? 0;
        _imageHeight = double.tryParse(hs)?.toInt() ?? 0;
      }
    } catch (_) {
      // ignore parse errors
    }
  }

  /// 加载当前文件的相邻文件列表，用于上/下一张导航。
  void _loadAdjacentFiles(String path) {
    final files = _fileService.getAdjacentFiles(path);
    _files = files.map((f) => f.path).toList();
    _currentIndex = _files.indexOf(path);
  }

  Future<void> nextFile() async {
    if (_currentIndex < _files.length - 1) {
      await openFile(_files[_currentIndex + 1]);
    }
  }

  Future<void> previousFile() async {
    if (_currentIndex > 0) {
      await openFile(_files[_currentIndex - 1]);
    }
  }

  void closeImage() {
    _imageBytes = null;
    _svgBytes = null;
    _isSvg = false;
    _currentPath = null;
    _files = [];
    _currentIndex = -1;
    _imageWidth = 0;
    _imageHeight = 0;
    _fileSize = 0;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
