import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ShoppingListPage extends StatefulWidget {
  final String username;

  const ShoppingListPage({super.key, required this.username});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  static const _storage = FlutterSecureStorage();
  final _itemController = TextEditingController();
  final List<_ShoppingItem> _items = [];

  String get _storageKey => 'shopping_list_${widget.username}';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final storedItems = await _storage.read(key: _storageKey);
      if (storedItems == null) return;
      final data = jsonDecode(storedItems);
      if (data is! List || !mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(
            data.whereType<Map<String, dynamic>>().map(_ShoppingItem.fromJson),
          );
      });
    } catch (_) {
      // A corrupt local list should not prevent the page from opening.
    }
  }

  Future<void> _saveItems() async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final name = _itemController.text.trim();

    if (name.isEmpty) return;

    setState(() {
      _items.add(_ShoppingItem(name));
    });

    _itemController.clear();
    await _saveItems();
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
              setState(() {
                _items.removeWhere((item) => item.isCompleted);
              });
              await _saveItems();
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
                                  setState(() {
                                    _items.removeAt(index);
                                  });
                                  await _saveItems();
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),

                              onChanged: (value) async {
                                setState(() {
                                  item.isCompleted = value ?? false;
                                });
                                await _saveItems();
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
  final String name;
  bool isCompleted;

  _ShoppingItem(this.name, {this.isCompleted = false});

  factory _ShoppingItem.fromJson(Map<String, dynamic> json) => _ShoppingItem(
    json['name']?.toString() ?? '',
    isCompleted: json['is_completed'] == true,
  );

  Map<String, dynamic> toJson() => {'name': name, 'is_completed': isCompleted};
}
