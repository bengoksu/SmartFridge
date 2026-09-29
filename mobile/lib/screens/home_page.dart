import 'package:flutter/material.dart';
import 'add_product_page.dart';

class HomePage extends StatelessWidget {
  final String accessToken;

  const HomePage({super.key, required this.accessToken});
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
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFCF4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Son Kullanma Tarihi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Şimdilik yaklaşan ürün yok.',
                    style: TextStyle(color: Color(0xFF4B5563)),
                  ),
                ],
              ),
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
                const _HomeCard(
                  icon: Icons.kitchen_outlined,
                  title: 'Buzdolabım',
                  subtitle: 'Ürünlerini görüntüle',
                ),

                _HomeCard(
                  icon: Icons.add_circle_outline,
                  title: 'Ürün Ekle',
                  subtitle: 'Yeni ürün ekle',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddProductPage(accessToken: accessToken),
                      ),
                    );
                  },
                ),

                const _HomeCard(
                  icon: Icons.groups_outlined,
                  title: 'Ailem',
                  subtitle: 'Ortak buzdolabı',
                ),

                const _HomeCard(
                  icon: Icons.restaurant_menu,
                  title: 'Ne Pişirsem?',
                  subtitle: 'AI yemek önerisi',
                ),
              ],
            ),

            const SizedBox(height: 26),

            const Text(
              'Genel Durum',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 14),

            const Row(
              children: [
                Expanded(
                  child: _StatCard(value: '0', label: 'Ürün'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatCard(value: '0', label: 'Yaklaşan SKT'),
                ),
              ],
            ),
          ],
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
