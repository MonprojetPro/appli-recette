import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget réutilisable pour afficher une photo de recette.
/// Gère les URLs Supabase Storage avec cache, placeholder et fallback.
class RecipePhotoWidget extends StatelessWidget {
  const RecipePhotoWidget({
    required this.photoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.restaurant,
    this.fallbackIconSize = 48,
    this.borderRadius,
    super.key,
  });

  final String? photoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final BorderRadius? borderRadius;

  bool get _isNetworkUrl =>
      photoUrl != null &&
      photoUrl!.isNotEmpty &&
      (photoUrl!.startsWith('http://') || photoUrl!.startsWith('https://'));

  /// Blob URLs (web) : valides pour Image.network mais pas pour CachedNetworkImage.
  bool get _isBlobUrl =>
      photoUrl != null &&
      photoUrl!.isNotEmpty &&
      photoUrl!.startsWith('blob:');

  @override
  Widget build(BuildContext context) {
    if (!_isNetworkUrl && !_isBlobUrl) {
      return _FallbackWidget(
        icon: fallbackIcon,
        iconSize: fallbackIconSize,
        width: width,
        height: height,
      );
    }

    late Widget image;

    if (_isBlobUrl) {
      // Blob URLs (photos d'étapes sur web) : Image.network directement
      image = Image.network(
        photoUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _FallbackWidget(
          icon: fallbackIcon,
          iconSize: fallbackIconSize,
          width: width,
          height: height,
        ),
      );
    } else {
      // HTTP(S) URLs : CachedNetworkImage avec cache
      image = CachedNetworkImage(
        imageUrl: photoUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: 800,
        placeholder: (_, _) => _PlaceholderWidget(
          width: width,
          height: height,
        ),
        errorWidget: (_, _, _) => _FallbackWidget(
          icon: fallbackIcon,
          iconSize: fallbackIconSize,
          width: width,
          height: height,
        ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

class _PlaceholderWidget extends StatelessWidget {
  const _PlaceholderWidget({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceVariant,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _FallbackWidget extends StatelessWidget {
  const _FallbackWidget({
    required this.icon,
    required this.iconSize,
    this.width,
    this.height,
  });
  final IconData icon;
  final double iconSize;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.primary.withAlpha(20),
      child: Center(
        child: Icon(icon, color: AppColors.primary, size: iconSize),
      ),
    );
  }
}
