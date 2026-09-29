import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FridgePage extends StatefulWidget {
  final String accessToken;

  const FridgePage({super.key, required this.accessToken});

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoEntrance;
  late final Animation<double> _fridgeExit;
  late final Animation<double> _listEntrance;
  List<_Product> _products = [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoEntrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .30, curve: Curves.easeOutBack),
    );
    _fridgeExit = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.54, .74, curve: Curves.easeInCubic),
    );
    _listEntrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.62, 1, curve: Curves.easeOutCubic),
    );

    _loadProducts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    _controller.reset();
    setState(() => _loadError = null);
    _controller.animateTo(
      .50,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/fridge/products/'),
        headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Sunucu yanıtı: ${response.statusCode}');
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final products = decoded
          .map((item) => _Product.fromJson(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() => _products = products);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Ürünler yüklenemedi.');
    }

    if (!mounted) return;
    await _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F7),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Buzdolabım',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Ürünleri yenile',
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                if (_fridgeExit.value < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 1 - _fridgeExit.value,
                        child: Transform.scale(
                          scale:
                              _logoEntrance.value *
                              (1 - (_fridgeExit.value * .12)),
                          child: Center(
                            child: Transform.translate(
                              offset: const Offset(0, -28),
                              child: const _FridgeLogo(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _listEntrance.value < .95,
                    child: Opacity(
                      opacity: _listEntrance.value,
                      child: Transform.translate(
                        offset: Offset(0, 28 * (1 - _listEntrance.value)),
                        child: _loadError == null
                            ? _ProductContent(products: _products)
                            : _LoadError(onRetry: _loadProducts),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FridgeLogo extends StatelessWidget {
  const _FridgeLogo();

  @override
  Widget build(BuildContext context) {
    const width = 156.0;
    const height = 206.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 13,
                right: 5,
                bottom: -5,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .12),
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(100, 18),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF55C9F6), Color(0xFF1687EB)],
                    ),
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x35177DD1),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF8FCFF), Color(0xFFDCEFFF)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Spacer(),
                        _shelf(),
                        const Spacer(),
                        _shelf(),
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.all(11),
                          height: 35,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .72),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFB9DCF7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 25,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0875DA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Positioned(
                right: 25,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0875DA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Positioned.fill(
                bottom: 7,
                child: Transform.scale(
                  alignment: Alignment.centerLeft,
                  scale: 1,
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0032)
                      ..rotateY(0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF69D5F8),
                            Color(0xFF27A9F3),
                            Color(0xFF147BE1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(
                          color: const Color(0xFF178FEA),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .15),
                            blurRadius: 15,
                            offset: const Offset(6, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          const Positioned(
                            left: 15,
                            top: 20,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.eco_rounded,
                                  color: Color(0xFF43D35D),
                                  size: 17,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'SmartFridge',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 11,
                            top: 37,
                            bottom: 35,
                            child: Container(
                              width: 6,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFFFFF),
                                    Color(0xFFD8F1FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33066AB8),
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'Ürünlerin hazırlanıyor',
          style: TextStyle(
            color: Color(0xFF526158),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: 90,
          child: LinearProgressIndicator(
            minHeight: 3,
            borderRadius: BorderRadius.all(Radius.circular(4)),
            backgroundColor: Color(0xFFE1E9E4),
            color: Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }

  static Widget _shelf() {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8FCBF4), Color(0xFFE4F5FF)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ProductContent extends StatelessWidget {
  final List<_Product> products;

  const _ProductContent({required this.products});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dolabındaki ürünler',
                      style: TextStyle(
                        color: Color(0xFF17211B),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Son kullanma tarihlerini kolayca takip et.',
                      style: TextStyle(color: Color(0xFF718078), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8ED),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${products.length} ürün',
                  style: const TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (products.isEmpty)
            const _EmptyFridge()
          else
            ...products.asMap().entries.map(
              (entry) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 280 + entry.key * 90),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(18 * (1 - value), 0),
                    child: child,
                  ),
                ),
                child: _ProductCard(product: entry.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F2419),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color: Color(0xFF202B24),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.amount,
                  style: const TextStyle(
                    color: Color(0xFF7A8780),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              product.expiry,
              style: const TextStyle(
                color: Color(0xFF526158),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Product {
  final String name;
  final String expiry;
  final String amount;

  const _Product(this.name, this.expiry, this.amount);

  factory _Product.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'İsimsiz ürün';
    final quantity = json['quantity']?.toString() ?? '1';
    final unit = (json['unit'] as String?)?.trim() ?? '';
    final rawDate = json['expiry_date'] as String?;

    return _Product(
      name,
      _formatDate(rawDate),
      unit.isEmpty ? '$quantity adet' : '$quantity $unit',
    );
  }

  static String _formatDate(String? value) {
    if (value == null || value.isEmpty) return 'Tarih yok';
    final parts = value.split('-');
    if (parts.length != 3) return value;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }
}

class _EmptyFridge extends StatelessWidget {
  const _EmptyFridge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5ECE8)),
      ),
      child: const Column(
        children: [
          Icon(Icons.kitchen_outlined, size: 44, color: Color(0xFF9AAC9F)),
          SizedBox(height: 12),
          Text(
            'Buzdolabında henüz ürün yok.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF526158),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: Color(0xFF9AAC9F),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ürünler yüklenemedi.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}
