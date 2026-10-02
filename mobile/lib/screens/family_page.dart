import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class FamilyPage extends StatefulWidget {
  final String accessToken;

  const FamilyPage({super.key, required this.accessToken});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  final _familyNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  bool _isLoading = true;

  Map<String, dynamic>? _household;

  @override
  void initState() {
    super.initState();

    _loadMyHousehold();
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    _inviteCodeController.dispose();

    super.dispose();
  }

  Future<void> _loadMyHousehold() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/households/my/'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          if (data.isNotEmpty) {
            _household = data.first;
          } else {
            _household = null;
          }
        });
      }
    } catch (e) {
      _showMessage('Aile bilgileri alınamadı.');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _createHousehold() async {
    final name = _familyNameController.text.trim();

    if (name.isEmpty) {
      _showMessage('Lütfen aile adı girin.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/households/create/'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({'name': name}),
      );

      if (response.statusCode == 201) {
        _familyNameController.clear();

        _showMessage('Aile başarıyla oluşturuldu.');

        await _loadMyHousehold();
      } else {
        _showMessage('Aile oluşturulamadı.');
      }
    } catch (e) {
      _showMessage('Sunucuya bağlanılamadı.');
    }
  }

  Future<void> _joinHousehold() async {
    final inviteCode = _inviteCodeController.text.trim();

    if (inviteCode.isEmpty) {
      _showMessage('Lütfen davet kodunu girin.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/households/join/'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({'invite_code': inviteCode}),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        _inviteCodeController.clear();

        _showMessage(data['detail'] ?? 'Aileye katıldınız.');

        await _loadMyHousehold();
      } else {
        _showMessage(data['detail'] ?? 'Aileye katılınamadı.');
      }
    } catch (e) {
      _showMessage('Sunucuya bağlanılamadı.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: const Text(
          'Ailem',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _household != null
          ? _buildHouseholdCard()
          : _buildNoHousehold(),
    );
  }

  Widget _buildHouseholdCard() {
    final name = _household?['name']?.toString() ?? '';

    final owner = _household?['owner_username']?.toString() ?? '';

    final inviteCode = _household?['invite_code']?.toString() ?? '';

    final members = _household?['members'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5ECE8)),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Icon(
                  Icons.family_restroom_rounded,
                  size: 42,
                  color: Color(0xFF22C55E),
                ),

                const SizedBox(height: 14),

                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Aile yöneticisi: $owner',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),

                const SizedBox(height: 6),

                Text(
                  '${members.length} aile üyesi',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Davet Kodu',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5ECE8)),
            ),

            child: Row(
              children: [
                Expanded(
                  child: Text(
                    inviteCode,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

                IconButton(
                  tooltip: 'Kopyala',

                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));

                    _showMessage('Davet kodu kopyalandı.');
                  },

                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Bu kodu aile üyelerinle paylaşabilirsin.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHousehold() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Henüz bir aileye bağlı değilsiniz.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 8),

          const Text(
            'Yeni bir aile oluşturabilir veya davet koduyla mevcut bir aileye katılabilirsiniz.',
            style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
          ),

          const SizedBox(height: 28),

          const Text(
            'Aile Oluştur',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _familyNameController,

            decoration: InputDecoration(
              hintText: 'Örn. Balaban Ailesi',
              filled: true,
              fillColor: Colors.white,

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,

            child: FilledButton(
              onPressed: _createHousehold,

              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),

                padding: const EdgeInsets.symmetric(vertical: 15),
              ),

              child: const Text('Aile Oluştur'),
            ),
          ),

          const SizedBox(height: 32),

          const Divider(),

          const SizedBox(height: 24),

          const Text(
            'Davet Koduyla Katıl',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _inviteCodeController,

            decoration: InputDecoration(
              hintText: 'Davet kodunu girin',
              filled: true,
              fillColor: Colors.white,

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton(
              onPressed: _joinHousehold,

              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),

              child: const Text('Aileye Katıl'),
            ),
          ),
        ],
      ),
    );
  }
}
