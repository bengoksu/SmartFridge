import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'add_product_page.dart';
import 'fridge_page.dart';
import 'shopping_list_page.dart';
import 'family_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({super.key, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<_ExpiryProduct> _products = [];
  bool _isLoadingProducts = true;

  List<_ExpiryProduct> get _expiringProducts =>
      _products.where((product) => product.daysRemaining <= 5).toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await ApiService.instance.get('/api/fridge/products/');
      if (response.statusCode != 200) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return;
      final products = data
          .whereType<Map<String, dynamic>>()
          .map(_ExpiryProduct.fromJson)
          .whereType<_ExpiryProduct>()
          .toList();
      if (mounted) setState(() => _products = products);
    } catch (_) {
      // The rest of the home screen remains usable when products cannot load.
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _loadProducts();
  }

  Future<void> _showExpiryNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExpiryNotificationsSheet(
        products: _expiringProducts,
        onOpenFridge: () {
          Navigator.pop(context);
          _openPage(const FridgePage());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'SmartFridge',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Bildirimler',
            onPressed: _showExpiryNotifications,
            icon: Badge.count(
              count: _expiringProducts.length,
              isLabelVisible: _expiringProducts.isNotEmpty,
              child: const Icon(Icons.notifications_none),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(username: widget.username),
                ),
              );
            },
          ),

          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hoş geldin 👋',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bugün buzdolabında neler var bakalım.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 28),
            _ExpiryWarningCard(
              products: _expiringProducts,
              isLoading: _isLoadingProducts,
            ),
            const SizedBox(height: 24),
            const Text(
              'Hızlı İşlemler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.2,
              children: [
                _HomeCard(
                  icon: Icons.kitchen_outlined,
                  title: 'Buzdolabım',
                  subtitle: 'Ürünlerini görüntüle',
                  onTap: () {
                    _openPage(const FridgePage());
                  },
                ),
                _HomeCard(
                  icon: Icons.add_circle_outline,
                  title: 'Ürün Ekle',
                  subtitle: 'Yeni ürün ekle',
                  onTap: () {
                    _openPage(const AddProductPage());
                  },
                ),
                _HomeCard(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Alışveriş Listesi',
                  subtitle: 'Eksikleri not al',
                  onTap: () {
                    _openPage(const ShoppingListPage());
                  },
                ),
                _HomeCard(
                  icon: Icons.family_restroom_outlined,
                  title: 'Ailem',
                  subtitle: 'Aile üyelerini görüntüle',
                  onTap: () {
                    _openPage(const FamilyPage());
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _AiRecipeCard(),
            const SizedBox(height: 26),
            const Text(
              'Genel Durum',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(value: '${_products.length}', label: 'Ürün'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    value: '${_expiringProducts.length}',
                    label: 'Yaklaşan SKT',
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

class _ExpiryWarningCard extends StatelessWidget {
  final List<_ExpiryProduct> products;
  final bool isLoading;

  const _ExpiryWarningCard({required this.products, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final hasWarning = products.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasWarning ? const Color(0xFFFFF7ED) : const Color(0xFFEFFCF4),
        borderRadius: BorderRadius.circular(20),
        border: hasWarning ? Border.all(color: const Color(0xFFFED7AA)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316)),
              SizedBox(width: 8),
              Text(
                'Son Kullanma Tarihi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const LinearProgressIndicator()
          else if (!hasWarning)
            const Text(
              'Önümüzdeki 5 gün içinde yaklaşan ürün yok.',
              style: TextStyle(color: Color(0xFF4B5563)),
            )
          else
            ...products.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      product.warningText,
                      style: TextStyle(
                        color: product.daysRemaining < 0
                            ? Colors.red
                            : const Color(0xFFEA580C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpiryNotificationsSheet extends StatelessWidget {
  final List<_ExpiryProduct> products;
  final VoidCallback onOpenFridge;

  const _ExpiryNotificationsSheet({
    required this.products,
    required this.onOpenFridge,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bildirimler',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          products.isEmpty
                              ? 'Her şey yolunda'
                              : '${products.length} ürün dikkat bekliyor',
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (products.isEmpty)
              const Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 44),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 58,
                        color: Color(0xFF22C55E),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Yaklaşan son kullanma tarihi yok',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Önümüzdeki 5 gün için uyarı gerektiren bir ürün bulunmuyor.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final expired = product.daysRemaining < 0;
                    final color = expired
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFEA580C);
                    final background = expired
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFFFF7ED);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: background),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              expired
                                  ? Icons.error_outline_rounded
                                  : Icons.schedule_rounded,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'SKT: ${product.formattedDate}',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              product.warningText,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenFridge,
                  icon: const Icon(Icons.kitchen_outlined),
                  label: const Text('Buzdolabını Görüntüle'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryProduct {
  final String name;
  final DateTime expiryDate;

  const _ExpiryProduct({required this.name, required this.expiryDate});

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return expiryDate.difference(today).inDays;
  }

  String get warningText {
    final days = daysRemaining;
    if (days < 0) return '${-days} gün geçti';
    if (days == 0) return 'Bugün doluyor';
    if (days == 1) return 'Yarın doluyor';
    return '$days gün kaldı';
  }

  String get formattedDate =>
      '${expiryDate.day.toString().padLeft(2, '0')}.'
      '${expiryDate.month.toString().padLeft(2, '0')}.'
      '${expiryDate.year}';

  static _ExpiryProduct? fromJson(Map<String, dynamic> json) {
    final rawDate = json['expiry_date']?.toString();
    final parsedDate = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (parsedDate == null) return null;
    return _ExpiryProduct(
      name: json['name']?.toString() ?? 'İsimsiz ürün',
      expiryDate: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
    );
  }
}

class _AiRecipeCard extends StatelessWidget {
  const _AiRecipeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF5B4FE9), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x295B4FE9),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Ne Pişirsem?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    _AiBadge(),
                  ],
                ),
                SizedBox(height: 5),
                Text(
                  'Dolabındaki ürünlerle sana özel tarif bul',
                  style: TextStyle(color: Color(0xFFE9E7FF), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 23,
          ),
        ],
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDDD6FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'AI',
        style: TextStyle(
          color: Color(0xFF5B21B6),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: const Color(0xFF22C55E)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}
