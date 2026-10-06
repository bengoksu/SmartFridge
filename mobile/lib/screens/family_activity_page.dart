import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class FamilyActivityPage extends StatefulWidget {
  const FamilyActivityPage({super.key});

  @override
  State<FamilyActivityPage> createState() => _FamilyActivityPageState();
}

class _FamilyActivityPageState extends State<FamilyActivityPage> {
  List<_FamilyActivity> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.instance.get(
        '/api/households/activities/',
      );
      if (!mounted) return;

      if (response.statusCode != 200) {
        var message = 'Aile hareketleri yüklenemedi.';
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map && data['detail'] is String) {
            message = data['detail'] as String;
          }
        } catch (_) {
          // JSON olmayan sunucu hatalarında genel mesajı kullan.
        }
        setState(() => _errorMessage = message);
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) {
        setState(() => _errorMessage = 'Aile hareketleri okunamadı.');
        return;
      }

      setState(() {
        _activities = data
            .whereType<Map<String, dynamic>>()
            .map(_FamilyActivity.fromJson)
            .toList();
      });
    } catch (error) {
      debugPrint('AİLE HAREKETLERİ HATASI: $error');
      if (mounted) {
        setState(
          () => _errorMessage =
              'Aile hareketleri alınamadı. Bağlantını kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Aile Hareketleri',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 54,
                color: Color(0xFF94A39A),
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF526158), height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadActivities,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (_activities.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadActivities,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            Icon(
              Icons.history_toggle_off_rounded,
              size: 64,
              color: Color(0xFFA2AEA7),
            ),
            SizedBox(height: 16),
            Text(
              'Henüz aile hareketi yok.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF526158),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: _activities.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _ActivityCard(activity: _activities[index]),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _FamilyActivity activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final appearance = _appearanceFor(activity.actionType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F2419),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: appearance.color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(appearance.icon, color: appearance.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.message,
                  style: const TextStyle(
                    color: Color(0xFF202B24),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: appearance.color.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        appearance.label,
                        style: TextStyle(
                          color: appearance.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _formatDateTime(activity.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF7A8780),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyActivity {
  final String actionType;
  final String message;
  final DateTime? createdAt;

  const _FamilyActivity({
    required this.actionType,
    required this.message,
    required this.createdAt,
  });

  factory _FamilyActivity.fromJson(Map<String, dynamic> json) {
    return _FamilyActivity(
      actionType: json['action_type']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class _ActivityAppearance {
  final IconData icon;
  final Color color;
  final String label;

  const _ActivityAppearance(this.icon, this.color, this.label);
}

_ActivityAppearance _appearanceFor(String actionType) {
  return switch (actionType) {
    'product_added' => const _ActivityAppearance(
      Icons.add_circle_outline_rounded,
      Color(0xFF16A34A),
      'ÜRÜN EKLENDİ',
    ),
    'product_updated' => const _ActivityAppearance(
      Icons.edit_outlined,
      Color(0xFF2563EB),
      'ÜRÜN GÜNCELLENDİ',
    ),
    'product_deleted' => const _ActivityAppearance(
      Icons.delete_outline_rounded,
      Color(0xFFDC2626),
      'ÜRÜN SİLİNDİ',
    ),
    'product_consumed' => const _ActivityAppearance(
      Icons.check_circle_outline_rounded,
      Color(0xFF0D9488),
      'ÜRÜN TÜKENDİ',
    ),
    'shopping_item_added' => const _ActivityAppearance(
      Icons.playlist_add_rounded,
      Color(0xFF7C3AED),
      'LİSTEYE EKLENDİ',
    ),
    'shopping_item_deleted' => const _ActivityAppearance(
      Icons.playlist_remove_rounded,
      Color(0xFFEA580C),
      'LİSTEDEN SİLİNDİ',
    ),
    'shopping_item_completed' => const _ActivityAppearance(
      Icons.shopping_bag_outlined,
      Color(0xFF0891B2),
      'SATIN ALINDI',
    ),
    _ => const _ActivityAppearance(
      Icons.history_rounded,
      Color(0xFF64748B),
      'AİLE HAREKETİ',
    ),
  };
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Tarih bilgisi yok';
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} • $hour:$minute';
}
