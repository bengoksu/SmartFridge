import 'package:flutter/material.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final _itemController = TextEditingController();
  final List<_ShoppingItem> _items = [];

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemController.text.trim();

    if (name.isEmpty) return;

    setState(() {
      _items.add(_ShoppingItem(name));
    });

    _itemController.clear();
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
            onPressed: () {
              setState(() {
                _items.removeWhere((item) => item.isCompleted);
              });
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
                                onPressed: () {
                                  setState(() {
                                    _items.removeAt(index);
                                  });
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),

                              onChanged: (value) {
                                setState(() {
                                  item.isCompleted = value ?? false;
                                });
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
  bool isCompleted = false;

  _ShoppingItem(this.name);
}
