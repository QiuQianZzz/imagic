enum ImageBackground {
  checkerboard('栅格'),
  darkCheckerboard('深色栅格'),
  solidWhite('纯白'),
  solidBlack('纯黑'),
  solidLightGray('浅灰'),
  solidGray('灰色'),
  solidDarkGray('深灰');

  final String label;
  const ImageBackground(this.label);

  static ImageBackground fromName(
    String? name, {
    ImageBackground fallback = ImageBackground.checkerboard,
  }) {
    if (name == null) return fallback;
    for (final v in ImageBackground.values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
