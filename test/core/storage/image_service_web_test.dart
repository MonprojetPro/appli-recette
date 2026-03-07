import 'dart:typed_data';

import 'package:appli_recette/core/storage/image_service.dart';
import 'package:appli_recette/core/storage/image_service_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('WebImageService.compressImage', () {
    late WebImageService service;

    setUp(() {
      service = WebImageService();
    });

    test('returns original bytes when image cannot be decoded', () async {
      final corruptBytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      final result = await service.compressImage(corruptBytes);
      expect(result, equals(corruptBytes));
    });

    test('compresses a small image and keeps it under 500KB', () async {
      // Créer une image 200x200 en mémoire
      final image = img.Image(width: 200, height: 200);
      img.fill(image, color: img.ColorRgb8(255, 128, 0));
      final bytes = Uint8List.fromList(img.encodePng(image));

      final compressed = await service.compressImage(bytes);
      expect(compressed.length, lessThanOrEqualTo(ImageService.maxSizeBytes));
    });

    test('compresses a large image to under 500KB via resize fallback',
        () async {
      // Créer une image 2000x2000 avec du bruit (difficile à compresser)
      final image = img.Image(width: 2000, height: 2000);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgb(x, y, (x * 7) % 256, (y * 13) % 256, (x + y) % 256);
        }
      }
      final bytes = Uint8List.fromList(img.encodePng(image));

      final compressed = await service.compressImage(bytes);
      expect(compressed.length, lessThanOrEqualTo(ImageService.maxSizeBytes));
    });

    test('output is valid JPEG', () async {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(0, 128, 255));
      final bytes = Uint8List.fromList(img.encodePng(image));

      final compressed = await service.compressImage(bytes);

      // Les fichiers JPEG commencent par les octets FF D8
      expect(compressed[0], equals(0xFF));
      expect(compressed[1], equals(0xD8));
    });
  });
}
