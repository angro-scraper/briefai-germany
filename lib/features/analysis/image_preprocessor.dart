import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PreprocessedImage {
  const PreprocessedImage({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

/// Produces an OCR-friendly JPEG entirely on-device. The transform applies the
/// EXIF rotation, limits extreme camera resolution and slightly increases
/// contrast. Returning null preserves the original file for unsupported data.
PreprocessedImage? preprocessImageForOcr({
  required String name,
  required Uint8List bytes,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  if (image.width > 2400) {
    image = img.copyResize(
      image,
      width: 2400,
      interpolation: img.Interpolation.cubic,
    );
  }
  image = img.adjustColor(image, contrast: 1.16, brightness: 1.03);
  final baseName = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
  return PreprocessedImage(
    name: '$baseName.jpg',
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 90)),
    mimeType: 'image/jpeg',
  );
}
