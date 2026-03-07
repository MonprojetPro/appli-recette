import 'dart:typed_data';

import 'package:appli_recette/core/storage/image_service_native.dart'
    if (dart.library.js_interop) 'package:appli_recette/core/storage/image_service_web.dart'
    as platform;

/// Service cross-platform de gestion des photos de recettes.
/// Gère la sélection, la compression (< 500 Ko) et la suppression.
abstract class ImageService {
  /// Factory retournant l'implémentation adaptée à la plateforme.
  factory ImageService() => platform.createImageService();

  /// Sélectionne une image depuis la galerie.
  /// Retourne les bytes bruts ou null si annulé.
  Future<Uint8List?> pickFromGallery();

  /// Sélectionne une image depuis la caméra.
  /// Retourne les bytes bruts ou null si annulé.
  Future<Uint8List?> pickFromCamera();

  /// Compresse l'image à < 500 Ko (JPEG).
  /// Retourne les bytes compressés.
  Future<Uint8List> compressImage(Uint8List bytes);

  /// Taille maximale acceptée pour une photo (500 Ko).
  static const int maxSizeBytes = 500 * 1024;
}
