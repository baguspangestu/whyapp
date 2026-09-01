import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  _createPaddedIcon(
    'assets/images/splash_icon_light.png',
    'assets/images/splash_icon_android12_light.png',
  );
  _createPaddedIcon(
    'assets/images/splash_icon_dark.png',
    'assets/images/splash_icon_android12_dark.png',
  );
}

void _createPaddedIcon(String inputPath, String outputPath) {
  final source = img.decodePng(File(inputPath).readAsBytesSync());
  if (source == null) throw StateError('Unable to decode $inputPath');

  // Android 12+ masks splash artwork to a circle. Keeping the visible mark at
  // 60% of the canvas places the bubble and its tail inside the safe diameter.
  final mark = img.copyResize(
    source,
    width: 614,
    height: 614,
    interpolation: img.Interpolation.cubic,
  );
  final canvas = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.compositeImage(canvas, mark, dstX: 205, dstY: 205);
  File(outputPath).writeAsBytesSync(img.encodePng(canvas));
}
