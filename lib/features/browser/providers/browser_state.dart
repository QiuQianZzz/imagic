import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../models/directory_entry.dart';
import '../../../core/constants/image_formats.dart';

class BrowserState extends ChangeNotifier {
  String? _currentDir;
  List<DirectoryEntry> _entries = [];
  List<DirectoryEntry> _imageFiles = [];

  String? get currentDir => _currentDir;
  List<DirectoryEntry> get entries => _entries;
  List<DirectoryEntry> get imageFiles => _imageFiles;

  void navigateTo(String path) {
    _currentDir = path;
    refresh();
  }

  void refresh() {
    if (_currentDir == null) return;
    final dir = _currentDir!;

    _entries = Directory(dir).listSync().map((e) {
      final isDir = e is Directory;
      return DirectoryEntry(
        path: e.path,
        name: p.basename(e.path),
        isDirectory: isDir,
      );
    }).where((e) {
      if (e.isDirectory) return true;
      final ext = p.extension(e.path).toLowerCase();
      return kSupportedExtensions.contains(ext);
    }).toList()
      ..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });

    _imageFiles = _entries.where((e) => !e.isDirectory).toList();
    notifyListeners();
  }
}
