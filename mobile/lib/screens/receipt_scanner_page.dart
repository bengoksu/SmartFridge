import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'receipt_camera_page.dart';

class ReceiptScannerPage extends StatefulWidget {
  const ReceiptScannerPage({super.key});

  @override
  State<ReceiptScannerPage> createState() => _ReceiptScannerPageState();
}

class _ReceiptScannerPageState extends State<ReceiptScannerPage> {
  final ImagePicker _picker = ImagePicker();
  final List<_ReceiptProductDraft> _detectedProducts = [];

  XFile? _selectedImage;
  bool _isAnalyzing = false;
  bool _isAddingProducts = false;

  @override
  void dispose() {
    _disposeDetectedProducts();
    super.dispose();
  }

  void _disposeDetectedProducts() {
    for (final product in _detectedProducts) {
      product.dispose();
    }
    _detectedProducts.clear();
  }

  void _setSelectedImage(XFile image) {
    _disposeDetectedProducts();
    setState(() => _selectedImage = image);
  }

  Future<void> _pickFromCamera() async {
    final image = await Navigator.of(
      context,
    ).push<XFile>(MaterialPageRoute(builder: (_) => const ReceiptCameraPage()));
    if (image == null || !mounted) return;
    _setSelectedImage(image);
  }

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    _setSelectedImage(image);
  }

  void _clearImage() {
    _disposeDetectedProducts();
    setState(() => _selectedImage = null);
  }

  Future<void> _analyzeReceipt() async {
    if (_selectedImage == null || _isAnalyzing) return;
    setState(() => _isAnalyzing = true);

    try {
      final bytes = await File(_selectedImage!.path).readAsBytes();
      final response = await ApiService.instance.postMultipart(
        '/api/fridge/receipt/analyze/',
        fields: {},
        fileBytes: bytes,
        fileName: _selectedImage!.name,
        fileField: 'receipt',
      );
      final responseBody = utf8.decode(response.bodyBytes);
      debugPrint(
        'FİŞ ANALİZ RESPONSE: status=${response.statusCode}, '
        'body=$responseBody',
      );

      if (!mounted) return;
      if (response.statusCode != 200) {
        _showMessage(_receiptErrorMessage(response.statusCode, responseBody));
        return;
      }

      final products = _parseDetectedProducts(jsonDecode(responseBody));
      _disposeDetectedProducts();
      setState(() => _detectedProducts.addAll(products));
      _showMessage(
        products.isEmpty
            ? 'Fişte eklenebilecek ürün bulunamadı.'
            : '${products.length} ürün algılandı.',
      );
    } catch (error) {
      debugPrint('FİŞ ANALİZ HATASI: $error');
      if (mounted) _showMessage('Sunucuya bağlanılamadı.');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  List<_ReceiptProductDraft> _parseDetectedProducts(dynamic data) {
    if (data is! Map<String, dynamic> || data['products'] is! List) return [];

    return (data['products'] as List)
        .whereType<Map<String, dynamic>>()
        .map((product) {
          final name = product['name']?.toString().trim() ?? '';
          final parsedQuantity = int.tryParse(
            product['quantity']?.toString() ?? '',
          );
          if (name.isEmpty) return null;
          return _ReceiptProductDraft(
            name: name,
            quantity: parsedQuantity != null && parsedQuantity > 0
                ? parsedQuantity
                : 1,
            unit: _normalizedUnit(product['unit']),
          );
        })
        .whereType<_ReceiptProductDraft>()
        .toList();
  }

  String _normalizedUnit(dynamic value) {
    final unit = value?.toString().trim().toLowerCase() ?? '';
    return switch (unit) {
      'kg' || 'kilogram' => 'kg',
      'g' || 'gr' || 'gram' => 'g',
      'l' || 'lt' || 'litre' || 'liter' => 'litre',
      'ml' || 'mililitre' || 'mililiter' => 'ml',
      'paket' || 'pk' => 'paket',
      'adet' || 'ad' => 'adet',
      _ => 'adet',
    };
  }

  Future<void> _pickExpiryDate(_ReceiptProductDraft product) async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: product.expiryDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (selectedDate != null && mounted) {
      setState(() => product.expiryDate = selectedDate);
    }
  }

  void _removeProduct(_ReceiptProductDraft product) {
    setState(() => _detectedProducts.remove(product));
    product.dispose();
  }

  Future<void> _addSelectedProducts() async {
    if (_isAddingProducts) return;
    final selected = _detectedProducts
        .where((product) => product.isSelected)
        .toList();

    if (selected.isEmpty) {
      _showMessage('En az bir ürün seçin.');
      return;
    }

    var hasValidationError = false;
    for (final product in selected) {
      final quantity = int.tryParse(product.quantityController.text.trim());
      if (product.nameController.text.trim().isEmpty ||
          quantity == null ||
          quantity < 1) {
        product.errorMessage = 'Ürün adı ve geçerli miktar gerekli.';
        hasValidationError = true;
      } else {
        product.errorMessage = null;
      }
    }
    if (hasValidationError) {
      setState(() {});
      return;
    }

    setState(() => _isAddingProducts = true);
    final added = <_ReceiptProductDraft>[];
    var failedCount = 0;

    for (final product in selected) {
      try {
        final response = await ApiService.instance.post(
          '/api/fridge/products/',
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json; charset=UTF-8',
          },
          body: utf8.encode(
            jsonEncode({
              'name': product.nameController.text.trim(),
              'quantity': int.parse(product.quantityController.text.trim()),
              'unit': product.unitController.text.trim().isEmpty
                  ? 'adet'
                  : product.unitController.text.trim(),
              'expiry_date': product.expiryDate == null
                  ? null
                  : _formatApiDate(product.expiryDate!),
            }),
          ),
        );
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint(
          'FİŞ ÜRÜN EKLEME RESPONSE: status=${response.statusCode}, '
          'body=$responseBody',
        );

        if (response.statusCode == 201) {
          added.add(product);
        } else {
          failedCount++;
          product.errorMessage = _productSaveError(
            response.statusCode,
            responseBody,
          );
        }
      } catch (error) {
        debugPrint('FİŞ ÜRÜN EKLEME HATASI: $error');
        failedCount++;
        product.errorMessage = 'Sunucuya bağlanılamadı.';
      }
    }

    if (!mounted) return;
    setState(() {
      for (final product in added) {
        _detectedProducts.remove(product);
        product.dispose();
      }
      _isAddingProducts = false;
    });

    if (failedCount == 0) {
      _disposeDetectedProducts();
      setState(() => _selectedImage = null);
      _showMessage('Ürünler buzdolabına eklendi.');
    } else {
      _showMessage(
        '${added.length} ürün eklendi, $failedCount ürün eklenemedi.',
      );
    }
  }

  String _formatApiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';

  String _productSaveError(int statusCode, String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] is String) return decoded['detail'] as String;
        return decoded.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' ');
      }
    } catch (_) {
      // JSON olmayan yanıtlarda durum kodu gösterilir.
    }
    return 'Ürün eklenemedi (HTTP $statusCode).';
  }

  String _receiptErrorMessage(int statusCode, String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // JSON olmayan yanıtlarda durum koduna göre güvenli mesaj gösterilir.
    }
    return switch (statusCode) {
      400 => 'Geçersiz veya eksik fiş görseli gönderildi.',
      401 => 'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.',
      413 => 'Fiş görseli çok büyük. En fazla 10 MB yükleyebilirsiniz.',
      500 || 502 => 'Fiş analiz servisi şu anda yanıt veremiyor.',
      _ => 'Fiş analiz edilemedi (HTTP $statusCode).',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F9F7),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Fiş Tara',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildImagePreview(),
            const SizedBox(height: 20),
            _buildImageButtons(),
            const SizedBox(height: 20),
            _buildAnalyzeButton(),
            if (_detectedProducts.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildDetectedProducts(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                  'Fişini tara',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Market fişindeki ürünleri otomatik olarak algılayacağız.',
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
          Icon(Icons.receipt_long_rounded, color: Colors.white, size: 42),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE4EBE7)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 72,
              color: Color(0xFF9AA59E),
            ),
            SizedBox(height: 16),
            Text(
              'Henüz fiş seçilmedi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF253129),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Kameradan fotoğraf çekebilir veya galeriden seçebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF78857D)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4EBE7)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              File(_selectedImage!.path),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isAnalyzing || _isAddingProducts ? null : _clearImage,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Fotoğrafı kaldır'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageButtons() {
    final disabled = _isAnalyzing || _isAddingProducts;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galeriden Seç'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: disabled ? null : _pickFromCamera,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Fotoğraf Çek'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF22C55E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _selectedImage == null || _isAnalyzing || _isAddingProducts
            ? null
            : _analyzeReceipt,
        icon: _isAnalyzing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(
          _isAnalyzing ? 'Analiz ediliyor...' : 'Fişi Analiz Et',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1596EB),
          disabledBackgroundColor: const Color(0xFFD9E1DD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectedProducts() {
    final selectedCount = _detectedProducts
        .where((product) => product.isSelected)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Algılanan ürünler',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Eklenmeden önce ürünleri kontrol edebilirsin.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78857D)),
                  ),
                ],
              ),
            ),
            Text(
              '$selectedCount/${_detectedProducts.length} seçili',
              style: const TextStyle(
                color: Color(0xFF1596EB),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._detectedProducts.map(_buildProductCard),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: selectedCount == 0 || _isAddingProducts || _isAnalyzing
                ? null
                : _addSelectedProducts,
            icon: _isAddingProducts
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.kitchen_rounded),
            label: Text(
              _isAddingProducts
                  ? 'Ürünler ekleniyor...'
                  : 'Seçilenleri Buzdolabına Ekle',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              disabledBackgroundColor: const Color(0xFFD9E1DD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(_ReceiptProductDraft product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: product.errorMessage == null
              ? const Color(0xFFE4EBE7)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: product.isSelected,
            onChanged: _isAddingProducts
                ? null
                : (value) =>
                      setState(() => product.isSelected = value ?? false),
          ),
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: product.nameController,
                  enabled: !_isAddingProducts,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ürün adı',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: product.quantityController,
                        enabled: !_isAddingProducts,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Miktar',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: product.unitController,
                        enabled: !_isAddingProducts,
                        decoration: const InputDecoration(
                          labelText: 'Birim',
                          hintText: 'adet',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isAddingProducts
                            ? null
                            : () => _pickExpiryDate(product),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                        ),
                        label: Text(
                          product.expiryDate == null
                              ? 'SKT: Belirtilmedi'
                              : 'SKT: ${_formatDisplayDate(product.expiryDate!)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (product.expiryDate != null)
                      IconButton(
                        tooltip: 'Tarihi kaldır',
                        onPressed: _isAddingProducts
                            ? null
                            : () => setState(() => product.expiryDate = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
                if (product.errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      product.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ürünü listeden çıkar',
            onPressed: _isAddingProducts ? null : () => _removeProduct(product),
            icon: const Icon(Icons.delete_outline_rounded),
            color: const Color(0xFF78857D),
          ),
        ],
      ),
    );
  }
}

class _ReceiptProductDraft {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  bool isSelected;
  DateTime? expiryDate;
  String? errorMessage;

  _ReceiptProductDraft({
    required String name,
    required int quantity,
    required String unit,
  }) : nameController = TextEditingController(text: name),
       quantityController = TextEditingController(text: quantity.toString()),
       unitController = TextEditingController(text: unit),
       isSelected = true;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}
