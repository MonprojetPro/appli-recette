import 'package:appli_recette/core/storage/image_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageService', () {
    test('maxSizeBytes is 500 KB', () {
      expect(ImageService.maxSizeBytes, equals(500 * 1024));
    });

    test('factory constructor creates an instance', () {
      // Le conditional import rend l'implémentation dépendante de la plateforme.
      // En contexte de test (non-web), NativeImageService est instancié.
      final service = ImageService();
      expect(service, isNotNull);
    });
  });
}
