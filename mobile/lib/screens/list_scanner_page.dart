import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'receipt_camera_page.dart';

class ListScannerPage extends StatefulWidget {
  const ListScannerPage({super.key});

  @override
  State<ListScannerPage> createState() => _ListScannerPageState();
}

class _ListScannerPageState extends State<ListScannerPage> {
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  PlatformFile? _selectedPdf;
  bool _isAnalyzing = false;

  List<Map<String, dynamic>> _detectedItems = [];

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _selectedImage = image;
      _selectedPdf = null;
      _detectedItems = [];
    });
  }

  Future<void> _pickFromCamera() async {
    final image = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        builder: (_) => const ReceiptCameraPage(
          title: 'Liste Fotoğrafı Çek',
          instructions: 'Listenin tamamını kadraja alın ve sabit tutun.',
          permissionMessage:
              'Liste fotoğrafı çekmek için kamera izni vermelisiniz.',
        ),
      ),
    );

    if (image == null || !mounted) return;

    setState(() {
      _selectedImage = image;
      _selectedPdf = null;
      _detectedItems = [];
    });
  }

  Future<void> _pickPdf() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (file == null || !mounted) return;

      setState(() {
        _selectedPdf = file;
        _selectedImage = null;
        _detectedItems = [];
      });
    } catch (error) {
      debugPrint('PDF SEÇİM HATASI: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF seçilirken bir hata oluştu.')),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _detectedItems = [];
    });
  }

  void _clearPdf() {
    setState(() {
      _selectedPdf = null;
      _detectedItems = [];
    });
  }

  Future<void> _analyzeList() async {
    if (_selectedImage == null && _selectedPdf == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final selectedImage = _selectedImage;
      final selectedPdf = _selectedPdf;
      final List<int> bytes;
      final String fileName;
      final String fileField;

      if (selectedImage != null) {
        bytes = await File(selectedImage.path).readAsBytes();
        fileName = selectedImage.name;
        fileField = 'list_image';
      } else if (selectedPdf != null) {
        bytes = await selectedPdf.readAsBytes();
        fileName = selectedPdf.name;
        fileField = 'list_pdf';
      } else {
        return;
      }

      final response = await ApiService.instance.postMultipart(
        '/api/shopping/analyze-list/',
        fields: {},
        fileBytes: bytes,
        fileName: fileName,
        fileField: fileField,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        final items = data['items'];

        if (items is List) {
          setState(() {
            _detectedItems = items
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => {
                    'name': item['name']?.toString() ?? '',
                    'selected': true,
                  },
                )
                .where((item) => (item['name'] as String).trim().isNotEmpty)
                .toList();
          });
        }
      } else {
        var message = 'Liste analiz edilemedi: ${response.statusCode}';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData is Map && errorData['detail'] is String) {
            message = errorData['detail'] as String;
          }
        } catch (_) {
          // Sunucu JSON dışında bir hata döndürürse durum kodunu göster.
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      debugPrint('LİSTE ANALİZ HATASI: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liste analiz edilirken hata oluştu.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _addSelectedItems() async {
    final selectedItems = _detectedItems
        .where((item) => item['selected'] == true)
        .toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir ürün seçmelisin.')),
      );

      return;
    }

    int successCount = 0;

    for (final item in selectedItems) {
      final name = item['name']?.toString().trim() ?? '';

      if (name.isEmpty) continue;

      final response = await ApiService.instance.post(
        '/api/shopping/items/',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );

      if (response.statusCode == 201) {
        successCount++;
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$successCount ürün alışveriş listesine eklendi.'),
      ),
    );

    if (successCount > 0) {
      Navigator.pop(context);
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
          'Liste Tara',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
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
                          'Alışveriş listesini tara',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Diyet listesi veya alışveriş listesindeki ürünleri algılayıp alışveriş listene ekleyelim.',
                          style: TextStyle(
                            color: Color(0xFFF3E8FF),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.white,
                    size: 42,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_selectedImage == null && _selectedPdf == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE4EBE7)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      size: 72,
                      color: Color(0xFF9AA59E),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz liste seçilmedi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Fotoğraf çekebilir, galeriden görsel veya PDF seçebilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF78857D), fontSize: 12),
                    ),
                  ],
                ),
              )
            else if (_selectedImage != null)
              Container(
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
                        onPressed: _clearImage,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Fotoğrafı kaldır'),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE4EBE7)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFF7C3AED),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seçilen PDF',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78857D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedPdf?.name ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _clearPdf,
                      tooltip: 'PDF’yi kaldır',
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeriden Seç'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Fotoğraf Çek'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF Seç'),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_selectedImage == null && _selectedPdf == null) ||
                        _isAnalyzing
                    ? null
                    : _analyzeList,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isAnalyzing ? 'Analiz ediliyor...' : 'Listeyi Analiz Et',
                ),
              ),
            ),

            if (_detectedItems.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text(
                'Algılanan ürünler',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              ..._detectedItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return Card(
                  child: CheckboxListTile(
                    value: item['selected'] == true,
                    title: TextFormField(
                      initialValue: item['name'],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        _detectedItems[index]['name'] = value;
                      },
                    ),
                    onChanged: (value) {
                      setState(() {
                        _detectedItems[index]['selected'] = value ?? false;
                      });
                    },
                  ),
                );
              }),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addSelectedItems,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Seçilenleri Alışveriş Listesine Ekle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
