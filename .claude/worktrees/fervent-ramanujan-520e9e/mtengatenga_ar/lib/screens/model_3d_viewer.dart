import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../models/artifact.dart';
import '../theme/app_tokens.dart';

class Model3DViewer extends StatelessWidget {
  const Model3DViewer({super.key, required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    debugPrint('Device mode: 3D Preview');
    final modelUrl = artifact.model3dUrl?.trim();
    final hasModel = modelUrl != null && modelUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -55,
              child: _BackgroundOrb(
                size: 220,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: 30,
              left: -40,
              child: _BackgroundOrb(
                size: 190,
                color: AppColors.secondary.withValues(alpha: 0.10),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      _BackButton(onPressed: () => Navigator.of(context).pop()),
                      const Spacer(),
                      const _ModeBanner(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCard(artifact: artifact),
                        const SizedBox(height: AppSpacing.md),
                        _ViewerStage(
                          artifactName: artifact.name,
                          hasModel: hasModel,
                          modelUrl: modelUrl,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _DescriptionCard(
                          description: artifact.description,
                          category: artifact.category,
                          period: artifact.period,
                          hasModel: hasModel,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            artifact.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle.copyWith(
              color: Colors.white,
              fontSize: 34,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Upgrade phone for AR',
            style: AppText.cardSubtitle.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.touch_app, label: 'Drag to rotate'),
              _InfoPill(icon: Icons.zoom_in, label: 'Pinch to zoom'),
              _InfoPill(icon: Icons.open_with, label: 'Pan freely'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewerStage extends StatelessWidget {
  const _ViewerStage({
    required this.artifactName,
    required this.hasModel,
    this.modelUrl,
  });

  final String artifactName;
  final bool hasModel;
  final String? modelUrl;

  @override
  Widget build(BuildContext context) {
    final stageHeight = (MediaQuery.sizeOf(context).height * 0.42)
        .clamp(280.0, 420.0)
        .toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.threed_rotation,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive 3D Preview',
                      style: AppText.tileTitle.copyWith(
                        color: AppColors.textMain,
                      ),
                    ),
                    Text(
                      hasModel
                          ? 'Explore every angle of $artifactName'
                          : '3D source is currently unavailable',
                      style: AppText.tileSubtitle.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: stageHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.surfaceBorder),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.backgroundLight,
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasModel
                ? ModelViewer(
                    src: modelUrl!,
                    alt: artifactName,
                    ar: false,
                    autoRotate: true,
                    cameraControls: true,
                    disableZoom: false,
                  )
                : _NoModelView(artifactName: artifactName),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({
    required this.description,
    required this.category,
    required this.period,
    required this.hasModel,
  });

  final String? description;
  final String? category;
  final String? period;
  final bool hasModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: AppText.tileTitle.copyWith(color: AppColors.textMain),
          ),
          const SizedBox(height: 10),
          Text(
            description?.trim().isNotEmpty == true
                ? description!
                : 'No description available for this artifact.',
            style: AppText.cardSubtitle.copyWith(
              color: AppColors.textMuted,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (category?.isNotEmpty == true) _TagChip(label: category!),
              if (period?.isNotEmpty == true) _TagChip(label: period!),
              if (!hasModel) const _TagChip(label: '3D model unavailable'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.secondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AR is unavailable on this device, but this interactive model still gives a full visual tour.',
                    style: AppText.smallLabel.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.smallLabel.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _NoModelView extends StatelessWidget {
  const _NoModelView({required this.artifactName});

  final String artifactName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundLight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.threed_rotation,
                  size: 38,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '3D model not available yet for $artifactName.',
                textAlign: TextAlign.center,
                style: AppText.tileTitle.copyWith(
                  color: AppColors.textMain,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please check back after model upload.',
                textAlign: TextAlign.center,
                style: AppText.cardSubtitle.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_in_ar_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '3D Preview',
            style: AppText.smallLabel.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
