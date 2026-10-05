import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';

class AddProductPage extends StatefulWidget {
  final String? initialName;

  const AddProductPage({super.key, this.initialName});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();

  DateTime? expiryDate;
  bool isSaving = false;
  @override
  void initState() {
    super.initState();

    if (widget.initialName != null) {
      nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (selectedDate != null) {
      setState(() {
        expiryDate = selectedDate;
      });
    }
  }

  Future<void> saveProduct() async {
    final name = nameController.text.trim();
    final quantity = int.tryParse(quantityController.text.trim());
    final unit = unitController.text.trim();

    if (name.isEmpty || quantity == null || expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen gerekli alanları doldurun.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final response = await ApiService.instance.post(
        '/api/fridge/products/',
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json; charset=UTF-8',
        },
        body: utf8.encode(
          jsonEncode({
            'name': name,
            'quantity': quantity,
            'unit': unit,
            'expiry_date':
                '${expiryDate!.year.toString().padLeft(4, '0')}-'
                '${expiryDate!.month.toString().padLeft(2, '0')}-'
                '${expiryDate!.day.toString().padLeft(2, '0')}',
          }),
        ),
      );

      if (!mounted) return;
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün başarıyla eklendi.')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürün eklenemedi: ${response.statusCode}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sunucuya bağlanılamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F9F7),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Yeni Ürün',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AddProductHeader(),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE4EBE7)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C14281E),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldTitle(
                    title: 'Ürün bilgisi',
                    subtitle: 'Dolabına ne ekliyorsun?',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      hintText: 'Örn. Süt, domates, peynir',
                      prefixIcon: Icons.edit_outlined,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _FieldTitle(
                    title: 'Miktar ve birim',
                    subtitle: 'Ne kadar eklemek istiyorsun?',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            hintText: '1',
                            prefixIcon: Icons.numbers_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: unitController,
                          onChanged: (_) => setState(() {}),
                          decoration: _inputDecoration(
                            hintText: 'Birim',
                            prefixIcon: Icons.straighten_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['adet', 'kg', 'litre', 'paket']
                        .map(
                          (unit) => ChoiceChip(
                            label: Text(unit),
                            selected: unitController.text.trim() == unit,
                            selectedColor: const Color(0xFFDDF7E6),
                            side: BorderSide(
                              color: unitController.text.trim() == unit
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFE3E9E5),
                            ),
                            labelStyle: TextStyle(
                              color: unitController.text.trim() == unit
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF647168),
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) {
                              unitController.text = unit;
                              setState(() {});
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 22),
                  const _FieldTitle(
                    title: 'Son kullanma tarihi',
                    subtitle: 'Sana zamanında hatırlatalım.',
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: pickDate,
                      borderRadius: BorderRadius.circular(17),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: expiryDate == null
                              ? const Color(0xFFF7F9F8)
                              : const Color(0xFFEFFAF3),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: expiryDate == null
                                ? const Color(0xFFE2E8E4)
                                : const Color(0xFFB9E8C9),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.calendar_today_rounded,
                                color: Color(0xFF22C55E),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expiryDate == null
                                        ? 'Tarih seç'
                                        : '${expiryDate!.day.toString().padLeft(2, '0')}.'
                                              '${expiryDate!.month.toString().padLeft(2, '0')}.'
                                              '${expiryDate!.year}',
                                    style: const TextStyle(
                                      color: Color(0xFF253129),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    expiryDate == null
                                        ? 'Takvimden son günü belirle'
                                        : 'Hatırlatıcı için hazır',
                                    style: const TextStyle(
                                      color: Color(0xFF78857D),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF91A097),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: isSaving ? null : saveProduct,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(
                  isSaving ? 'Ekleniyor...' : 'Buzdolabına ekle',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9AA59E), fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF6C7A71), size: 20),
      filled: true,
      fillColor: const Color(0xFFF7F9F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8E4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
      ),
    );
  }
}

class _AddProductHeader extends StatelessWidget {
  const _AddProductHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1596EB), Color(0xFF35C7D9)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dolabını güncel tut',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Ürünü ekle, son kullanma tarihini birlikte takip edelim.',
                  style: TextStyle(
                    color: Color(0xFFE8FAFF),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 42),
        ],
      ),
    );
  }
}

class _FieldTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FieldTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF263229),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF839087), fontSize: 11),
        ),
      ],
    );
  }
}
