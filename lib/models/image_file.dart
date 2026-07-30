class ImageFile {
  final String path;
  final String name;
  final String extension;
  final int fileSize;

  ImageFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.fileSize,
  });

  String get format => extension.replaceAll('.', '').toUpperCase();
}
