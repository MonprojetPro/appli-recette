import 'dart:io';
import 'dart:typed_data';

import 'package:appli_recette/core/storage/image_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Implémentation native (iOS/Android) de [ImageService].
/// Utilise image_picker pour la sélection et flutter_image_compress.
ImageService createImageService() => NativeImageService();

class NativeImageService implements ImageService {
  NativeImageService() : _picker = ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pickFromGallery() => _pick(ImageSource.gallery);

  @override
  Future<Uint8List?> pickFromCamera() => _pick(ImageSource.camera);

  Future<Uint8List?> _pick(ImageSource source) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null) return null;
    return xFile.readAsBytes();
  }

  @override
  Future<Uint8List> compressImage(Uint8List bytes) async {
    // Écrire les bytes dans un fichier temporaire pour flutter_image_compress
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, '${const Uuid().v4()}.jpg');
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes);

    final targetPath = p.join(tempDir.path, '${const Uuid().v4()}_c.jpg');

    // Phase 1 : réduction de qualité à taille standard (1024px)
    for (final quality in [85, 70, 55, 40, 25]) {
      final xFile = await FlutterImageCompress.compressAndGetFile(
        tempPath,
        targetPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
      );
      if (xFile == null) continue;
      final result = await File(xFile.path).readAsBytes();
      if (result.length <= ImageService.maxSizeBytes) {
        await _cleanTemp(tempPath, targetPath);
        return result;
      }
    }

    // Phase 2 : réduction de dimensions si la qualité seule ne suffit pas
    for (final dim in [800, 600, 400]) {
      final xFile = await FlutterImageCompress.compressAndGetFile(
        tempPath,
        targetPath,
        quality: 30,
        minWidth: dim,
        minHeight: dim,
      );
      if (xFile == null) continue;
      final result = await File(xFile.path).readAsBytes();
      if (result.length <= ImageService.maxSizeBytes) {
        await _cleanTemp(tempPath, targetPath);
        return result;
      }
    }

    // Dernier recours : retourner la dernière compression tentée
    await _cleanTemp(tempPath, targetPath);
    return bytes;
  }

  Future<void> _cleanTemp(String sourcePath, String targetPath) async {
    try {
      final source = File(sourcePath);
      if (source.existsSync()) await source.delete();
      final target = File(targetPath);
      if (target.existsSync()) await target.delete();
    } on Exception catch (_) {
      // Ignorer les erreurs de nettoyage
    }
  }
}
