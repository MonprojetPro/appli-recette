import 'dart:typed_data';

import 'package:appli_recette/core/storage/image_service.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Implémentation web de [ImageService].
/// Utilise image_picker (qui utilise file input HTML) et le package `image`
/// (Dart pur) pour la compression.
ImageService createImageService() => WebImageService();

class WebImageService implements ImageService {
  WebImageService() : _picker = ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pickFromGallery() => _pick(ImageSource.gallery);

  @override
  Future<Uint8List?> pickFromCamera() => _pick(ImageSource.camera);

  Future<Uint8List?> _pick(ImageSource source) async {
    final xFile = await _picker.pickImage(source: source);
    if (xFile == null) return null;
    return xFile.readAsBytes();
  }

  @override
  Future<Uint8List> compressImage(Uint8List bytes) async {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      // Image corrompue ou format non supporté (RangeError, FormatException, etc.)
      return bytes;
    }
    if (decoded == null) return bytes;

    // Redimensionner si l'image est très grande
    var image = decoded;
    if (image.width > 1024 || image.height > 1024) {
      image = img.copyResize(
        image,
        width: image.width > image.height ? 1024 : null,
        height: image.height >= image.width ? 1024 : null,
      );
    }

    // Réduction progressive de la qualité
    for (final quality in [80, 60, 40]) {
      final compressed =
          Uint8List.fromList(img.encodeJpg(image, quality: quality));
      if (compressed.length <= ImageService.maxSizeBytes) return compressed;
    }

    // Si la qualité seule ne suffit pas, réduire aussi les dimensions
    for (final maxDim in [800, 600, 400]) {
      image = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? maxDim : null,
        height: decoded.height >= decoded.width ? maxDim : null,
      );
      final compressed =
          Uint8List.fromList(img.encodeJpg(image, quality: 40));
      if (compressed.length <= ImageService.maxSizeBytes) return compressed;
    }

    // Dernier recours : plus petite taille + qualité minimale
    return Uint8List.fromList(img.encodeJpg(image, quality: 20));
  }
}
