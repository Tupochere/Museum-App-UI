import 'package:flutter/material.dart';
import '../../core/domain/entities/artifact.model.dart';
import '../../theme/app_tokens.dart';

class ArtifactDetailsScreen extends StatefulWidget {
  const ArtifactDetailsScreen({
    super.key,
    this.artifact,
  });

  final Artifact? artifact;

  @override
  State<ArtifactDetailsScreen> createState() => _ArtifactDetailsScreenState();
}

class _ArtifactDetailsScreenState extends State<ArtifactDetailsScreen> {
  int _tabIndex = 0;

  // From Stitch camera-view background-image :contentReference[oaicite:1]{index=1}
  static const _cameraBgUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCz7m3hfZ7WDj7tuYMeFX6xHQPagTZzocE8zajP23BAGdJBaOEaXK5GSJpLNvAUTUFOSkh3jLrxhMhGWVe6-cr-BY1eA3hTTTsGX2LAs5J9bJYMoQ2_cTNa127AVJD5XS6kOyRsfS8vsJJEEnDUeAYRY7wmvF4A37vJUbUzNCXBEmZLEVVMlVGuuBya0PZgTZ62_kZwSRND--6asi1c75TSltkoTzbHLG2fQGmMGj3-2UuOEJw9CyrNfaoA9FeqjJj-Tx47tepZSjqG';

  // 3D thumb background-image :contentReference[oaicite:2]{index=2}
  static const _artifactThumbUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAKUlU05rK5MKuYlSuD-BV6n6QjIwPXAnNt0YxOA8FHBxpaG_2p4cOL-NTijM4YJsTDbVuyShtdG2e24WC9hRd9Tx7LO1_R5tCYxAZuazAl-IRXpNEfdjl4qA26t9iWYUyqQ8hTw1Zd37r-mW3yFHojYdSUjtUmW8exjZSAPXtsffU4TxJAiyFrxIud2vjA1vvuT_XgK2jcJ6c1Y5YJVLezGmP4TEHfkEYRdrvOtIe8oA4mzJ3zBNi1vBBZ1rKsXnYL9R9GPYpcten6';

  @override
  Widget build(BuildContext context) {
    final artifactThumbUrl =
        widget.artifact?.modelThumbnailUrl ??
        widget.artifact?.displayImageUrl ??
        _artifactThumbUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // AR camera background
          Positioned.fill(
            child: Image.network(
              _cameraBgUrl,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.10),
              colorBlendMode: BlendMode.darken,
            ),
          ),

          // AR Mode pill (top-left) :contentReference[oaicite:3]{index=3}
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.40),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 14,
                      offset: Offset(0, 6),
                      color: Color(0x14000000),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.view_in_ar, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'AR Mode Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center framing box (for AR alignment UI) :contentReference[oaicite:4]{index=4}
          Align(
            alignment: const Alignment(0, -0.05),
            child: _ArFrame(),
          ),

          // Bottom sheet overlay
          DraggableScrollableSheet(
            initialChildSize: 0.60, // ~60vh :contentReference[oaicite:5]{index=5}
            minChildSize: 0.40,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFDFBF7), // earth-light :contentReference[oaicite:6]{index=6}
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 30,
                      offset: Offset(0, -8),
                      color: Color(0x33000000),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6D3D1), // stone-300-ish :contentReference[oaicite:7]{index=7}
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header content (chips + title + thumb)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _HeaderTextBlock(artifact: widget.artifact),
                          ),
                          const SizedBox(width: 14),
                          _Thumb3D(
                            imageUrl: artifactThumbUrl,
                            onTap: () {
                              // UI only
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Open 3D (UI only)')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Actions row (Listen + heart + share) :contentReference[oaicite:8]{index=8}
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary, // primary in Stitch = #8D6E63 :contentReference[oaicite:9]{index=9}
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text(
                                  'Listen',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SquareIconButton(icon: Icons.favorite, onTap: () {}),
                          const SizedBox(width: 12),
                          _SquareIconButton(icon: Icons.share, onTap: () {}),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tabs :contentReference[oaicite:10]{index=10}
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _Tabs(
                        index: _tabIndex,
                        onChanged: (i) => setState(() => _tabIndex = i),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Scroll content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: _TabContent(
                          tabIndex: _tabIndex,
                          artifact: widget.artifact,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // matches Stitch: w-64 h-64 border + grid lines + corners :contentReference[oaicite:11]{index=11}
    const size = 256.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(height: 1, color: Colors.white.withOpacity(0.30)),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(width: 1, color: Colors.white.withOpacity(0.30)),
          ),
          const _FrameCorner(alignment: Alignment.topLeft, top: true, left: true),
          const _FrameCorner(alignment: Alignment.topRight, top: true, left: false),
          const _FrameCorner(alignment: Alignment.bottomLeft, top: false, left: true),
          const _FrameCorner(alignment: Alignment.bottomRight, top: false, left: false),
        ],
      ),
    );
  }
}

class _FrameCorner extends StatelessWidget {
  const _FrameCorner({
    required this.alignment,
    required this.top,
    required this.left,
  });

  final Alignment alignment;
  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 18,
        height: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: top ? BorderSide(color: Colors.white.withOpacity(0.60), width: 2) : BorderSide.none,
              bottom: !top ? BorderSide(color: Colors.white.withOpacity(0.60), width: 2) : BorderSide.none,
              left: left ? BorderSide(color: Colors.white.withOpacity(0.60), width: 2) : BorderSide.none,
              right: !left ? BorderSide(color: Colors.white.withOpacity(0.60), width: 2) : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderTextBlock extends StatelessWidget {
  const _HeaderTextBlock({this.artifact});

  final Artifact? artifact;

  @override
  Widget build(BuildContext context) {
    final category = artifact?.category?.toUpperCase() ?? 'CULTURAL HERITAGE';
    final period = artifact?.period ?? 'Unknown Period';
    final title = artifact?.name ?? 'Artifact Details';
    final location = artifact?.location ?? 'Location unavailable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE07A5F).withOpacity(0.10), // terracotta/10 :contentReference[oaicite:12]{index=12}
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: Color(0xFFE07A5F),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              period,
              style: TextStyle(
                color: Color(0xFF78716C), // stone-500
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textMain, // earth-dark :contentReference[oaicite:13]{index=13}
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          location,
          style: TextStyle(
            color: Color(0xFF78716C),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Thumb3D extends StatelessWidget {
  const _Thumb3D({required this.imageUrl, required this.onTap});
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFE7E5E4), // stone-200 :contentReference[oaicite:14]{index=14}
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6D3D1)), // stone-300
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(imageUrl, fit: BoxFit.cover),
            Container(
              color: Colors.black.withOpacity(0.10),
              alignment: Alignment.center,
              child: const Icon(Icons.threed_rotation, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F4), // stone-100 :contentReference[oaicite:15]{index=15}
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7E5E4)), // stone-200
        ),
        child: Icon(icon, color: const Color(0xFF57534E)), // stone-600
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, int i) {
      final active = index == i;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(i),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    color: active ? const Color(0xFFE07A5F) : const Color(0xFFA8A29E), // terracotta vs stone-400 :contentReference[oaicite:16]{index=16}
                  ),
                ),
              ),
              Container(
                height: 3,
                width: double.infinity,
                color: active ? const Color(0xFFE07A5F) : Colors.transparent,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7E5E4))), // stone-200 :contentReference[oaicite:17]{index=17}
      ),
      child: Row(
        children: [
          tab('Overview', 0),
          tab('History', 1),
          tab('Media', 2),
        ],
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tabIndex,
    this.artifact,
  });

  final int tabIndex;
  final Artifact? artifact;

  @override
  Widget build(BuildContext context) {
    switch (tabIndex) {
      case 1:
        return _HistoryTab(artifact: artifact);
      case 2:
        return _MediaTab(artifact: artifact);
      default:
        return _OverviewTab(artifact: artifact);
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({this.artifact});

  final Artifact? artifact;

  @override
  Widget build(BuildContext context) {
    final description = artifact?.description ?? 'No description is available for this artifact yet.';
    final significance = artifact?.culturalSignificance ??
        'Cultural significance details are not available yet for this artifact.';
    final notes = artifact?.additionalNotes ?? 'Additional notes are not available.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          description,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 18,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Cultural Significance',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          significance,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _InfoBox(artifact: artifact),
        const SizedBox(height: 18),
        Text(
          notes,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({this.artifact});

  final Artifact? artifact;

  @override
  Widget build(BuildContext context) {
    final period = artifact?.period ?? 'Unknown period';
    final location = artifact?.location ?? 'Unknown location';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F4), // stone-100 :contentReference[oaicite:18]{index=18}
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)), // stone-200
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFE07A5F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Period: $period\nLocation: $location',
              style: const TextStyle(
                color: Color(0xFF57534E),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({this.artifact});

  final Artifact? artifact;

  @override
  Widget build(BuildContext context) {
    final timeline = artifact?.timeline ?? const <TimelineEvent>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _SectionTitle('Timeline'),
        const SizedBox(height: 10),
        if (timeline.isEmpty)
          const _TimelineItem(year: 'N/A', text: 'No timeline information available for this artifact.'),
        for (final event in timeline) _TimelineItem(year: event.year, text: event.event),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({this.artifact});

  final Artifact? artifact;

  @override
  Widget build(BuildContext context) {
    final photoCount = artifact?.galleryImages?.length ?? 0;
    final videoCount = artifact?.videoUrls?.length ?? 0;
    final hasModel = (artifact?.model3dUrl?.isNotEmpty ?? false);

    return Column(
      children: [
        const SizedBox(height: 12),
        _SectionTitle('Media'),
        const SizedBox(height: 12),
        _MediaTile(icon: Icons.image_outlined, title: 'Photos', subtitle: '$photoCount image${photoCount == 1 ? '' : 's'}'),
        _MediaTile(icon: Icons.videocam_outlined, title: 'Videos', subtitle: '$videoCount clip${videoCount == 1 ? '' : 's'}'),
        _MediaTile(icon: Icons.threed_rotation, title: '3D Model', subtitle: hasModel ? 'Available' : 'Not available'),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.textMain,
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.year, required this.text});
  final String year;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              year,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textMain)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
