import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import 'add_product_page.dart';
import 'fridge_page.dart';
import 'shopping_list_page.dart';
import 'family_page.dart';
import 'profile_page.dart';
import 'recipe_result_page.dart';
import 'barcode_scanner_page.dart';

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({super.key, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _storage = FlutterSecureStorage();
  List<_ExpiryProduct> _products = [];
  Set<String> _readNotificationKeys = {};
  bool _isLoadingProducts = true;

  List<_ExpiryProduct> get _expiringProducts =>
      _products.where((product) => product.daysRemaining <= 5).toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  List<_ExpiryProduct> get _unreadProducts => _expiringProducts
      .where((product) => !_readNotificationKeys.contains(product.alertKey))
      .toList();

  String get _readNotificationsStorageKey =>
      'read_expiry_notifications_${widget.username}';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final storedReadKeys = await _storage.read(
        key: _readNotificationsStorageKey,
      );
      final response = await ApiService.instance.get('/api/fridge/products/');
      if (response.statusCode != 200) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return;
      final products = data
          .whereType<Map<String, dynamic>>()
          .map(_ExpiryProduct.fromJson)
          .whereType<_ExpiryProduct>()
          .toList();
      if (mounted) {
        setState(() {
          _products = products;
          _readNotificationKeys =
              storedReadKeys
                  ?.split('|')
                  .where((key) => key.isNotEmpty)
                  .toSet() ??
              {};
        });
      }
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
    final currentKeys = _expiringProducts
        .map((product) => product.alertKey)
        .toSet();
    if (currentKeys.isNotEmpty) {
      final updatedReadKeys = {..._readNotificationKeys, ...currentKeys};
      if (mounted) setState(() => _readNotificationKeys = updatedReadKeys);
      await _storage.write(
        key: _readNotificationsStorageKey,
        value: updatedReadKeys.join('|'),
      );
    }

    if (!mounted) return;
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
              count: _unreadProducts.length,
              isLabelVisible: _unreadProducts.isNotEmpty,
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
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (sheetContext) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ürün nasıl eklensin?',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                ListTile(
                                  leading: const Icon(Icons.edit_outlined),
                                  title: const Text('Manuel Ekle'),
                                  subtitle: const Text(
                                    'Ürün bilgilerini kendin gir',
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);

                                    _openPage(const AddProductPage());
                                  },
                                ),

                                const Divider(),

                                ListTile(
                                  leading: const Icon(Icons.qr_code_scanner),
                                  title: const Text('Barkod Tara'),
                                  subtitle: const Text(
                                    'Ürünün barkodunu kamerayla okut',
                                  ),
                                  onTap: () async {
                                    Navigator.pop(sheetContext);

                                    final barcode =
                                        await Navigator.push<String>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const BarcodeScannerPage(),
                                          ),
                                        );

                                    if (!context.mounted) return;

                                    if (barcode != null) {
                                      final response = await ApiService.instance
                                          .get('/api/fridge/barcode/$barcode/');

                                      if (!context.mounted) return;

                                      if (response.statusCode == 200) {
                                        final data = jsonDecode(
                                          utf8.decode(response.bodyBytes),
                                        );

                                        final name =
                                            data['name']?.toString() ?? '';
                                        final brand =
                                            data['brand']?.toString() ?? '';
                                        final quantityText =
                                            data['quantity_text']?.toString() ??
                                            '';
                                        final initialQuantity = data['quantity']
                                            ?.toString();
                                        final initialUnit = data['unit']
                                            ?.toString();

                                        showDialog(
                                          context: context,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              title: const Text('Ürün bulundu'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name.isEmpty
                                                        ? 'Ürün adı bulunamadı'
                                                        : name,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  if (brand.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text('Marka: $brand'),
                                                  ],
                                                  if (quantityText
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Paket: $quantityText',
                                                    ),
                                                  ],
                                                  const SizedBox(height: 8),
                                                  Text('Barkod: $barcode'),
                                                ],
                                              ),
                                              actions: [
                                                ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                      dialogContext,
                                                    );

                                                    _openPage(
                                                      AddProductPage(
                                                        initialName: name,
                                                        initialQuantity:
                                                            initialQuantity,
                                                        initialUnit:
                                                            initialUnit,
                                                      ),
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Buzdolabına Ekle',
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      } else if (response.statusCode == 404) {
                                        final manualContinue = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Ürün bulunamadı',
                                              ),
                                              content: Text(
                                                'Bu barkod ürün veritabanında bulunamadı.\n\n'
                                                'Barkod: $barcode\n\n'
                                                'Ürün bilgilerini manuel girmek ister misin?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                      dialogContext,
                                                      false,
                                                    );
                                                  },
                                                  child: const Text('Vazgeç'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                      dialogContext,
                                                      true,
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Manuel devam et',
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (!context.mounted) return;

                                        if (manualContinue == true) {
                                          await _openPage(
                                            const AddProductPage(),
                                          );
                                        }
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Ürün sorgulanamadı: ${response.statusCode}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),

                                const Divider(),

                                ListTile(
                                  leading: const Icon(
                                    Icons.receipt_long_outlined,
                                  ),
                                  title: const Text('Fiş Tara'),
                                  subtitle: const Text(
                                    'Market fişinden ürünleri otomatik çıkar',
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Fiş tarama yakında eklenecek.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                _HomeCard(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Alışveriş Listesi',
                  subtitle: 'Eksikleri not al',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (context) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Alışveriş listesi nasıl oluşturulsun?',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                ListTile(
                                  leading: const Icon(Icons.edit_outlined),
                                  title: const Text('Manuel Ekle'),
                                  subtitle: const Text('Ürünleri kendin ekle'),
                                  onTap: () {
                                    Navigator.pop(context);

                                    _openPage(
                                      ShoppingListPage(
                                        username: widget.username,
                                      ),
                                    );
                                  },
                                ),

                                const Divider(),

                                ListTile(
                                  leading: const Icon(
                                    Icons.document_scanner_outlined,
                                  ),
                                  title: const Text('Liste Tara'),
                                  subtitle: const Text(
                                    'Diyet veya alışveriş listesindeki ürünleri çıkar',
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Liste tarama yakında eklenecek.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
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
  final int? id;
  final String name;
  final DateTime expiryDate;

  const _ExpiryProduct({this.id, required this.name, required this.expiryDate});

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

  String get alertKey =>
      '${id ?? name}:${expiryDate.toIso8601String()}:'
      '${daysRemaining < 0 ? 'expired' : 'near'}';

  static _ExpiryProduct? fromJson(Map<String, dynamic> json) {
    final rawDate = json['expiry_date']?.toString();
    final parsedDate = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (parsedDate == null) return null;
    return _ExpiryProduct(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? 'İsimsiz ürün',
      expiryDate: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
    );
  }
}

class _AiRecipeCard extends StatelessWidget {
  const _AiRecipeCard();

  Future<void> _openRecipePreferences(BuildContext context) async {
    try {
      final response = await ApiService.instance.get('/api/fridge/products/');
      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is! List) throw const FormatException();
        final productNames =
            data
                .whereType<Map<String, dynamic>>()
                .map((product) => product['name']?.toString().trim())
                .whereType<String>()
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        if (productNames.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tarif önermek için önce buzdolabına ürün eklemelisin.',
              ),
            ),
          );
          return;
        }

        RecipePreferences? currentPreferences;
        while (true) {
          if (!context.mounted) return;
          final preferences = await showModalBottomSheet<RecipePreferences>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _RecipePreferencesSheet(
              productNames: productNames,
              initialPreferences: currentPreferences,
            ),
          );
          if (!context.mounted || preferences == null) return;
          currentPreferences = preferences;

          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecipeResultPage(preferences: preferences),
            ),
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürünler alınamadı: ${response.statusCode}')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürünler alınırken bir hata oluştu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openRecipePreferences(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
      ),
    );
  }
}

class _RecipePreferencesSheet extends StatefulWidget {
  final List<String> productNames;
  final RecipePreferences? initialPreferences;

  const _RecipePreferencesSheet({
    required this.productNames,
    this.initialPreferences,
  });

  @override
  State<_RecipePreferencesSheet> createState() =>
      _RecipePreferencesSheetState();
}

class _RecipePreferencesSheetState extends State<_RecipePreferencesSheet> {
  static const _mealTypes = {
    'any': 'Fark etmez',
    'main': 'Ana yemek',
    'menu': 'Menü',
    'breakfast': 'Kahvaltı',
    'snack': 'Atıştırmalık',
    'dessert': 'Tatlı',
  };
  static const _mealTimes = {
    'any': 'Fark etmez',
    'breakfast': 'Kahvaltı',
    'lunch': 'Öğle yemeği',
    'dinner': 'Akşam yemeği',
  };

  late String _mealType;
  late String _mealTime;
  late String? _preferredProduct;
  late int _servings;
  late int? _maxMinutes;

  @override
  void initState() {
    super.initState();
    final preferences = widget.initialPreferences;
    _mealType = preferences?.mealType ?? 'any';
    _mealTime = preferences?.mealTime ?? 'any';
    _preferredProduct = preferences?.preferredProduct;
    _servings = preferences?.servings ?? 2;
    _maxMinutes = preferences?.maxMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFEDE9FE),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF5B4FE9),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nasıl bir öneri istersin?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Tercihlerini seç, gerisini SmartFridge düşünsün.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _PreferenceLabel(
                icon: Icons.restaurant_menu_rounded,
                text: 'Ne tür bir şey istiyorsun?',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _mealType,
                decoration: _inputDecoration(),
                items: _mealTypes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _mealType = value ?? 'any'),
              ),
              const SizedBox(height: 18),
              _PreferenceLabel(
                icon: Icons.wb_sunny_outlined,
                text: 'Hangi öğün için?',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _mealTime,
                decoration: _inputDecoration(),
                items: _mealTimes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _mealTime = value ?? 'any'),
              ),
              const SizedBox(height: 18),
              _PreferenceLabel(
                icon: Icons.kitchen_outlined,
                text: 'Özellikle kullanmak istediğin ürün',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _preferredProduct,
                decoration: _inputDecoration(),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Fark etmez'),
                  ),
                  ...widget.productNames.map(
                    (name) => DropdownMenuItem<String?>(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _preferredProduct = value),
              ),
              const SizedBox(height: 18),
              _PreferenceLabel(
                icon: Icons.people_alt_outlined,
                text: 'Kaç kişilik?',
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
                  ButtonSegment(value: 5, label: Text('5+')),
                ],
                selected: {_servings},
                onSelectionChanged: (value) {
                  setState(() => _servings = value.first);
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 18),
              _PreferenceLabel(
                icon: Icons.schedule_rounded,
                text: 'Maksimum hazırlama süresi',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [null, 15, 30, 45]
                    .map(
                      (minutes) => ChoiceChip(
                        label: Text(
                          minutes == null ? 'Fark etmez' : '$minutes dk',
                        ),
                        selected: _maxMinutes == minutes,
                        onSelected: (_) =>
                            setState(() => _maxMinutes = minutes),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    RecipePreferences(
                      mealType: _mealType,
                      mealTime: _mealTime,
                      preferredProduct: _preferredProduct,
                      servings: _servings,
                      maxMinutes: _maxMinutes,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4FE9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text(
                    'Öneri Oluştur',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() => InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
  );
}

class _PreferenceLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PreferenceLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5B4FE9)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// Kept temporarily for compatibility with an already open result sheet.
// ignore: unused_element
class _RecipeResultSheet extends StatefulWidget {
  final String recipe;

  const _RecipeResultSheet({required this.recipe});

  @override
  State<_RecipeResultSheet> createState() => _RecipeResultSheetState();
}

class _RecipeResultSheetState extends State<_RecipeResultSheet> {
  late String _recipe = widget.recipe;
  bool _isLoading = false;

  Future<void> _getAnotherRecipe() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.instance.post('/api/ai/recipe/');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _recipe = data['recipe']?.toString() ?? 'Tarif alınamadı.';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarif alınamadı: ${response.statusCode}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarif alınırken bir hata oluştu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .9,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F7FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B4FE9), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Tarif Önerisi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 8),
                            _AiBadge(),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Dolabındaki ürünlere özel hazırlandı',
                          style: TextStyle(
                            color: Color(0xFFE9E7FF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE9E7F3)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D312E81),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 72),
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF5B4FE9),
                              ),
                              SizedBox(height: 18),
                              Text(
                                'Yeni tarif hazırlanıyor...',
                                style: TextStyle(
                                  color: Color(0xFF5B4FE9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SelectableText(
                          _recipe,
                          style: const TextStyle(
                            color: Color(0xFF27253A),
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Kapat'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _getAnotherRecipe,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5B4FE9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'Başka Tarif',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
