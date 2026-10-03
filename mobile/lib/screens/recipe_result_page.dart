import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class RecipePreferences {
  final String mealType;
  final String mealTime;
  final String? preferredProduct;
  final int servings;
  final int? maxMinutes;

  const RecipePreferences({
    this.mealType = 'any',
    this.mealTime = 'any',
    this.preferredProduct,
    this.servings = 2,
    this.maxMinutes,
  });

  Map<String, dynamic> toJson(List<String> previousRecipes) => {
    'meal_type': mealType,
    'meal_time': mealTime,
    'preferred_product': preferredProduct,
    'servings': servings,
    'max_minutes': maxMinutes,
    'previous_recipes': previousRecipes,
  };
}

class RecipeResultPage extends StatefulWidget {
  final RecipePreferences preferences;

  const RecipeResultPage({super.key, required this.preferences});

  @override
  State<RecipeResultPage> createState() => _RecipeResultPageState();
}

class _RecipeResultPageState extends State<RecipeResultPage> {
  String? _recipe;
  String? _initialError;
  bool _isLoading = false;
  List<String> _previousRecipes = [];

  @override
  void initState() {
    super.initState();
    _requestRecipe();
  }

  String _recipeName(String recipe) {
    final lines = recipe.split('\n');
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].trim().toLowerCase().startsWith('öneri adı:')) {
        final sameLine = lines[index].split(':').skip(1).join(':').trim();
        if (sameLine.isNotEmpty) return sameLine;
        if (index + 1 < lines.length && lines[index + 1].trim().isNotEmpty) {
          return lines[index + 1].trim();
        }
      }
    }
    return recipe.trim().split('\n').first;
  }

  Future<void> _requestRecipe() async {
    if (_isLoading) return;

    final previousRecipes = [..._previousRecipes];
    if (_recipe != null) {
      previousRecipes.add(_recipeName(_recipe!));
    }
    final recentRecipes = previousRecipes.length > 5
        ? previousRecipes.sublist(previousRecipes.length - 5)
        : previousRecipes;

    setState(() {
      _isLoading = true;
      _initialError = null;
    });

    try {
      final response = await ApiService.instance.post(
        '/api/ai/recipe/',
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(widget.preferences.toJson(recentRecipes)),
      );
      if (!mounted) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        final newRecipe = data['recipe']?.toString();
        if (newRecipe != null && newRecipe.trim().isNotEmpty) {
          setState(() {
            _recipe = newRecipe;
            _previousRecipes = recentRecipes;
            _isLoading = false;
          });
          return;
        }
      }

      final message = data is Map<String, dynamic>
          ? data['detail']?.toString()
          : null;
      _showError(message ?? 'Tarif alınamadı: ${response.statusCode}');
    } catch (_) {
      if (!mounted) return;
      _showError('Tarif alınırken bir hata oluştu.');
    }
  }

  void _showError(String message) {
    setState(() {
      _isLoading = false;
      if (_recipe == null) _initialError = message;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7FF),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Tarif Önerisi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            if (_recipe != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _requestRecipe,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4FE9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _isLoading
                          ? 'Yeni tarif hazırlanıyor...'
                          : 'Başka Tarif Öner',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_recipe == null && _isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF5B4FE9)),
            SizedBox(height: 18),
            Text(
              'Sana özel tarif hazırlanıyor...',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    if (_recipe == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 12),
              Text(_initialError ?? 'Tarif alınamadı.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _requestRecipe,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _RecipeContent(recipe: _recipe!),
    );
  }
}

class _RecipeContent extends StatelessWidget {
  final String recipe;

  const _RecipeContent({required this.recipe});

  static const _menuColors = [
    (Color(0xFFF1EFFF), Color(0xFF5B4FE9)),
    (Color(0xFFE0F7EC), Color(0xFF1D9A67)),
    (Color(0xFFFFF3E6), Color(0xFFDD7A00)),
    (Color(0xFFEAF2FF), Color(0xFF2563EB)),
  ];

  static const _summaryColors = [
    (Color(0xFFF5F3FF), Color(0xFF6D28D9)),
    (Color(0xFFEEF7FF), Color(0xFF1D4ED8)),
  ];

  @override
  Widget build(BuildContext context) {
    final sections = _parseRecipeSections(recipe);

    return Column(
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          _RecipeSectionCard(
            text: sections[index].text,
            backgroundColor: sections[index].backgroundColor,
            accentColor: sections[index].accentColor,
          ),
          if (index != sections.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<_RecipeSection> _parseRecipeSections(String recipe) {
    final lines = recipe.split('\n');
    final sections = <_RecipeSection>[];
    String? currentHeading;
    final buffer = <String>[];
    var activeMenuIndex = -1;

    void flush() {
      if (currentHeading == null) return;
      final content = buffer.join('\n').trim();
      if (content.isEmpty) return;

      final headingText = currentHeading!.trim();
      final normalized = headingText.toLowerCase();
      final isSummary =
          normalized.startsWith('toplam hazırlama süresi') ||
          normalized.startsWith('kısa not');

      final palette = activeMenuIndex >= 0 && !isSummary
          ? _menuColors[activeMenuIndex % _menuColors.length]
          : isSummary
          ? _summaryColors[0]
          : _summaryColors[1];

      sections.add(
        _RecipeSection(
          text: '$headingText:\n${content.trim()}',
          backgroundColor: palette.$1,
          accentColor: palette.$2,
        ),
      );
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (_isSectionHeading(trimmed)) {
        if (currentHeading != null) {
          flush();
          buffer.clear();
        }

        final menuMatch = RegExp(
          r'^menü\s+(\d+)\s*:?$',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (menuMatch != null) {
          activeMenuIndex = int.parse(menuMatch.group(1)!) - 1;
          final palette = _menuColors[activeMenuIndex % _menuColors.length];
          sections.add(
            _RecipeSection(
              text: 'Menü ${menuMatch.group(1)}:\n',
              backgroundColor: palette.$1,
              accentColor: palette.$2,
            ),
          );
          currentHeading = null;
          buffer.clear();
          continue;
        }

        currentHeading = trimmed.endsWith(':')
            ? trimmed.substring(0, trimmed.length - 1).trim()
            : trimmed.trim();
        continue;
      }

      if (currentHeading != null) {
        buffer.add(line);
      }
    }

    if (currentHeading != null) {
      flush();
    }

    return sections;
  }

  bool _isSectionHeading(String line) {
    if (line.isEmpty) return false;
    final normalized = line.toLowerCase();
    if (normalized.startsWith('öneri adı:') ||
        normalized.startsWith('öneri türü:') ||
        normalized.startsWith('kullanılacak malzemeler:') ||
        normalized.startsWith('hazırlama süresi:') ||
        normalized.startsWith('yapılışı:') ||
        normalized.startsWith('kısa not:') ||
        normalized.startsWith('toplam hazırlama süresi:') ||
        normalized.startsWith('menü ') ||
        normalized.startsWith('menü:') ||
        normalized.startsWith('yemek adı:')) {
      return true;
    }
    return false;
  }
}

class _RecipeSection {
  final String text;
  final Color backgroundColor;
  final Color accentColor;

  const _RecipeSection({
    required this.text,
    required this.backgroundColor,
    required this.accentColor,
  });
}

class _RecipeSectionCard extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color accentColor;

  const _RecipeSectionCard({
    required this.text,
    required this.backgroundColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final firstLine = lines.first.trim();
    final hasHeading = firstLine.endsWith(':');
    final heading = hasHeading
        ? firstLine.substring(0, firstLine.length - 1)
        : null;
    final content = hasHeading ? lines.skip(1).join('\n').trim() : text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) ...[
            Row(
              children: [
                Icon(_iconFor(heading), size: 19, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    heading,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (content.isNotEmpty) const SizedBox(height: 10),
          ],
          if (content.isNotEmpty)
            SelectableText(
              content,
              style: TextStyle(
                color: const Color(0xFF27253A),
                fontSize: heading == 'Öneri Adı' ? 19 : 14.5,
                fontWeight: heading == 'Öneri Adı'
                    ? FontWeight.w800
                    : FontWeight.w500,
                height: 1.55,
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String heading) {
    final normalized = heading.toLowerCase();
    if (normalized.contains('malzeme')) return Icons.shopping_basket_outlined;
    if (normalized.contains('süre')) return Icons.schedule_rounded;
    if (normalized.contains('yapılış')) {
      return Icons.format_list_numbered_rounded;
    }
    if (normalized.contains('menü')) return Icons.restaurant_menu_rounded;
    if (normalized.contains('not')) return Icons.lightbulb_outline_rounded;
    if (normalized.contains('tür')) return Icons.category_outlined;
    return Icons.auto_awesome_rounded;
  }
}
