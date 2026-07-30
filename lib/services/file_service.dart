import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../core/constants/image_formats.dart';
import '../models/image_file.dart';

class FileService {
  Future<String?> openFileDialog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kSupportedExtensions
          .map((e) => e.replaceFirst('.', ''))
          .toList(),
    );
    return result?.files.single.path;
  }

  List<ImageFile> listDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    return dir.listSync().where((e) {
      if (e is! File) return false;
      final ext = extensionOf(e.path);
      return kSupportedExtensions.contains(ext);
    }).map((e) {
      final file = e as File;
      final stat = file.statSync();
      return ImageFile(
        path: file.path,
        name: p.basename(file.path),
        extension: extensionOf(file.path),
        fileSize: stat.size,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ImageFile> getAdjacentFiles(String currentPath) {
    final dir = Directory(currentPath).parent;
    return listDirectory(dir.path);
  }

  static String extensionOf(String path) {
    return p.extension(path).toLowerCase();
  }
}
