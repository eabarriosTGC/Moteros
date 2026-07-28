/// PhotoAlbum — grid de fotos de conquest_photos desde Supabase Storage.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../data/models/conquest_photo_model.dart';

class PhotoAlbum extends StatelessWidget {
  final List<ConquestPhotoModel> photos;

  const PhotoAlbum({super.key, this.photos = const []});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.camera,
                  color: AppColors.secondary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('ÁLBUM DE CONQUISTAS',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  )),
              const Spacer(),
              Text('${photos.length} fotos',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: photos.length > 9 ? 9 : photos.length,
            itemBuilder: (_, i) => _photoThumbnail(context, photos[i]),
          ),
        ],
      ),
    );
  }

  Widget _photoThumbnail(BuildContext context, ConquestPhotoModel photo) {
    return GestureDetector(
      onTap: () => _showPhotoFullscreen(context, photo),
      child: ClipRRect(
        borderRadius: AppRadius.smCircular,
        child: Image.network(
          photo.photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.surface,
            child: const Icon(AppIcons.error,
                color: AppColors.textMuted, size: 24),
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AppColors.surface,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPhotoFullscreen(BuildContext context, ConquestPhotoModel photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: photo.caption != null && photo.caption!.isNotEmpty
                ? Text(photo.caption!,
                    style: const TextStyle(color: Colors.white))
                : null,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                photo.photoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text('Error al cargar imagen',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
