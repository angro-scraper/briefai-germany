import 'dart:io';

import 'package:image/image.dart' as img;

/// Produces opaque iOS AppIcon assets from the approved BriefAI logo source.
///
/// Keep this tool with the source so a future marketing version can regenerate
/// every required AppIcon size consistently instead of hand-editing PNG files.
void main() {
  const sourcePath = 'assets/branding/briefai_logo_v2_source.png';
  const renderedLogoPath = 'assets/branding/briefai_logo_v2.png';
  const iosDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const androidDirectory = 'android/app/src/main/res';

  final source = img.decodeImage(File(sourcePath).readAsBytesSync());
  if (source == null) {
    throw StateError('Could not decode $sourcePath');
  }

  final master = img.copyResize(
    source,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );

  // Apple icons must be opaque. Generated logos sometimes carry transparent
  // pixels around the rounded mark; composite them on BriefAI navy.
  final opaque = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.fill(opaque, color: img.ColorRgba8(16, 27, 61, 255));
  img.compositeImage(opaque, master);
  File(renderedLogoPath).writeAsBytesSync(img.encodePng(opaque, level: 9));

  const sizes = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };

  for (final entry in sizes.entries) {
    final resized = img.copyResize(
      opaque,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    File(
      '$iosDirectory/${entry.key}',
    ).writeAsBytesSync(img.encodePng(resized, level: 9));
  }

  const androidSizes = <String, int>{
    'mipmap-mdpi/ic_launcher.png': 48,
    'mipmap-hdpi/ic_launcher.png': 72,
    'mipmap-xhdpi/ic_launcher.png': 96,
    'mipmap-xxhdpi/ic_launcher.png': 144,
    'mipmap-xxxhdpi/ic_launcher.png': 192,
    'drawable-mdpi/ic_launcher_foreground.png': 108,
    'drawable-hdpi/ic_launcher_foreground.png': 162,
    'drawable-xhdpi/ic_launcher_foreground.png': 216,
    'drawable-xxhdpi/ic_launcher_foreground.png': 324,
    'drawable-xxxhdpi/ic_launcher_foreground.png': 432,
  };
  for (final entry in androidSizes.entries) {
    final resized = img.copyResize(
      opaque,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    File(
      '$androidDirectory/${entry.key}',
    ).writeAsBytesSync(img.encodePng(resized, level: 9));
  }

  stdout.writeln(
    'Updated ${sizes.length} iOS and ${androidSizes.length} Android icons '
    'plus $renderedLogoPath',
  );
}
