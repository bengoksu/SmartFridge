import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ShoppingListPage extends StatefulWidget {
  final String username;

  const ShoppingListPage({super.key, required this.username});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final List<_ShoppingItem> _items = [];
  bool _isLoading = true;
  final _itemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final response = await ApiService.instance.get('/api/shopping/items/');

      if (response.statusCode != 200) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! List || !mounted) return;

      setState(() {
        _items
          ..clear()
          ..addAll(
            data.whereType<Map<String, dynamic>>().map(_ShoppingItem.fromJson),
          );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final name = _itemController.text.trim();

    if (name.isEmpty) return;

    final response = await ApiService.instance.post(
      '/api/shopping/items/',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 201) {
      _itemController.clear();

      await _loadItems();
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürün eklenemedi: ${response.statusCode}')),
      );
    }
  }

  Future<void> _handleItemToggle(_ShoppingItem item, bool newValue) async {
    if (newValue) {
      final addToFridge = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Ürün satın alındı'),
            content: Text('${item.name} buzdolabına eklensin mi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hayır'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Evet'),
              ),
            ],
          );
        },
      );

      if (addToFridge == true) {
        final quantityController = TextEditingController(text: '1');
        final unitController = TextEditingController(text: 'adet');
        final expiryController = TextEditingController();

        final shouldAdd = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text('${item.name} buzdolabına eklensin'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Miktar'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Birim',
                        hintText: 'adet, paket, kg, litre...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: expiryController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Son kullanma tarihi',
                        hintText: 'Tarih seç',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      onTap: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );

                        if (selectedDate != null) {
                          expiryController.text =
                              '${selectedDate.year}-'
                              '${selectedDate.month.toString().padLeft(2, '0')}-'
                              '${selectedDate.day.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Buzdolabına Ekle'),
                ),
              ],
            );
          },
        );

        if (shouldAdd == true) {
          final fridgeResponse = await ApiService.instance.post(
            '/api/fridge/products/',
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': item.name,
              'quantity': int.tryParse(quantityController.text.trim()) ?? 1,
              'unit': unitController.text.trim(),
              'expiry_date': expiryController.text.trim().isEmpty
                  ? null
                  : expiryController.text.trim(),
            }),
          );

          if (!mounted) return;

          if (fridgeResponse.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${item.name} buzdolabına eklendi.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Buzdolabına eklenemedi: ${fridgeResponse.statusCode}',
                ),
              ),
            );

            return;
          }
        }
      }
    }

    final response = await ApiService.instance.patch(
      '/api/shopping/items/${item.id}/',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'is_completed': newValue}),
    );

    if (response.statusCode == 200) {
      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _items.where((item) => !item.isCompleted).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Alışveriş Listesi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Tamamlananları temizle',
            onPressed: () async {
              final completedItems = _items
                  .where((item) => item.isCompleted)
                  .toList();

              for (final item in completedItems) {
                await ApiService.instance.delete(
                  '/api/shopping/items/${item.id}/',
                );
              }

              await _loadItems();
            },
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                remaining == 0
                    ? 'Liste hazır'
                    : '$remaining ürün alınmayı bekliyor',
                style: const TextStyle(
                  color: Color(0xFF526158),
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addItem(),
                      decoration: InputDecoration(
                        hintText: 'Ürün adı yazın',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  SizedBox(
                    width: 52,
                    height: 52,
                    child: FilledButton(
                      onPressed: _addItem,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFF22C55E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _items.isEmpty
                    ? const _EmptyShoppingList()
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5ECE8),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: item.isCompleted,
                              activeColor: const Color(0xFF22C55E),
                              controlAffinity: ListTileControlAffinity.leading,

                              title: Text(
                                item.name,
                                style: TextStyle(
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: item.isCompleted
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF1F2937),
                                ),
                              ),

                              secondary: IconButton(
                                tooltip: 'Sil',
                                onPressed: () async {
                                  final response = await ApiService.instance
                                      .delete(
                                        '/api/shopping/items/${item.id}/',
                                      );

                                  if (response.statusCode == 204) {
                                    await _loadItems();
                                  } else {
                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Ürün silinemedi: ${response.statusCode}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),

                              onChanged: (value) {
                                final newValue = value ?? false;
                                _handleItemToggle(item, newValue);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyShoppingList extends StatelessWidget {
  const _EmptyShoppingList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Alışveriş listeniz boş.\n'
        'Yukarıdan yeni bir ürün ekleyebilirsiniz.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
      ),
    );
  }
}

class _ShoppingItem {
  final int id;
  final String name;
  bool isCompleted;

  _ShoppingItem({
    required this.id,
    required this.name,
    this.isCompleted = false,
  });

  factory _ShoppingItem.fromJson(Map<String, dynamic> json) {
    return _ShoppingItem(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      isCompleted: json['is_completed'] == true,
    );
  }
}
