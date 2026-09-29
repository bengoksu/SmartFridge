import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddProductPage extends StatefulWidget {
  final String accessToken;

  const AddProductPage({super.key, required this.accessToken});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();

  DateTime? expiryDate;

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

    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/fridge/products/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer ${widget.accessToken}',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ürün başarıyla eklendi.')));

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürün eklenemedi: ${response.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Ürün Ekle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ürün adı',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Miktar',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Birim (adet, kg, litre...)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                expiryDate == null
                    ? 'Son kullanma tarihi seç'
                    : '${expiryDate!.day}.${expiryDate!.month}.${expiryDate!.year}',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: pickDate,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveProduct,
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
