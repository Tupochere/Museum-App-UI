import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/domain/repositories/artifact_repository.dart';
import '../../services/search_service.dart';
import '../../services/translation_service.dart';
import '../../theme/app_tokens.dart';
import '../artifact/artifact_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchService = GetIt.instance<SearchService>();
  final _translationService = GetIt.instance<TranslationService>();
  final _artifactRepo = GetIt.instance<IArtifactRepository>();
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  List<SearchResult>? _results;
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);

    final results = await _searchService.search(query);

    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  Future<void> _onResultTap(SearchResult result) async {
    final artifact = await _artifactRepo.getArtifactById(result.id);
    if (!mounted || artifact == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtifactDetailsScreen(artifact: artifact),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textMain,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                onSubmitted: (q) {
                  if (q.trim().isNotEmpty) _performSearch(q.trim());
                },
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 15,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search artifacts...',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_results == null) {
      return _buildEmptyState();
    }

    if (_results!.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildResultsList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search by name, period,\nmaterial, or cultural significance',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  label: 'Musical instruments',
                  onTap: () => _quickSearch('Musical instruments'),
                ),
                _SuggestionChip(
                  label: 'Chewa traditions',
                  onTap: () => _quickSearch('Chewa traditions'),
                ),
                _SuggestionChip(
                  label: 'Ceremonial masks',
                  onTap: () => _quickSearch('Ceremonial masks'),
                ),
                _SuggestionChip(
                  label: 'Pottery',
                  onTap: () => _quickSearch('Pottery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _quickSearch(String query) {
    _ctrl.text = query;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _performSearch(query);
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      itemBuilder: (_, __) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 200,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.40),
            ),
            const SizedBox(height: 16),
            const Text(
              'No artifacts matched your search.\nTry different keywords.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: _results!.length,
      itemBuilder: (_, i) => _SearchResultCard(
        result: _results![i],
        translationService: _translationService,
        onTap: () => _onResultTap(_results![i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search result card
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.translationService,
    required this.onTap,
  });

  final SearchResult result;
  final TranslationService translationService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final matchPercent = (result.similarity * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: result.displayImageUrl != null
                  ? Image.network(
                      result.displayImageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderIcon(),
                    )
                  : _placeholderIcon(),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (result.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            result.category!,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (result.period != null)
                        Flexible(
                          child: Text(
                            result.period!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (result.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.description!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Match badge + chevron
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$matchPercent%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.museum_outlined,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion chip
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
