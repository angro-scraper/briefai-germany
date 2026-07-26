import 'dart:typed_data';

import 'package:briefai_germany/features/analysis/image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('normalizes a large image into an OCR-friendly JPEG', () {
    final source = img.Image(width: 2600, height: 1300, numChannels: 3);
    img.fill(source, color: img.ColorRgb8(180, 180, 180));

    final processed = preprocessImageForOcr(
      name: 'brief.png',
      bytes: Uint8List.fromList(img.encodePng(source)),
    );

    expect(processed, isNotNull);
    expect(processed!.name, 'brief.jpg');
    expect(processed.mimeType, 'image/jpeg');
    expect(img.decodeJpg(processed.bytes)!.width, 2400);
  });
}
