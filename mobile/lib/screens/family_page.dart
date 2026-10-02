import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

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
      final response = await ApiService.instance.get('/api/households/my/');
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
      final response = await ApiService.instance.post(
        '/api/households/create/',
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'name': name}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          _household = data;
        });

        _familyNameController.clear();

        _showMessage('Aile başarıyla oluşturuldu.');
      } else {
        _showMessage('Aile oluşturulamadı: ${response.statusCode}');
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
      final response = await ApiService.instance.post(
        '/api/households/join/',
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
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

  Future<void> _leaveHousehold({bool creatingNew = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(creatingNew ? 'Yeni aile kur' : 'Aileden ayrıl'),
        content: Text(
          creatingNew
              ? 'Yeni bir aile kurmak için mevcut ailenizden ayrılmanız gerekiyor. Devam edilsin mi?'
              : 'Bu aileden ayrılmak istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(creatingNew ? 'Devam Et' : 'Ayrıl'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiService.instance.post('/api/households/leave/');
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _household = null);
        _showMessage(
          creatingNew
              ? 'Şimdi yeni ailenizi oluşturabilirsiniz.'
              : data['detail'] ?? 'Aileden ayrıldınız.',
        );
      } else {
        _showMessage(data['detail'] ?? 'Aileden ayrılamadınız.');
      }
    } catch (_) {
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
    final memberUsernames =
        _household?['member_usernames'] as List<dynamic>? ?? [];
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

                const SizedBox(height: 16),

                const Text(
                  'Aile Üyeleri',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 8),

                ...memberUsernames.map(
                  (username) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 8),
                        Text(username.toString()),
                      ],
                    ),
                  ),
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
                IconButton(
                  tooltip: 'Paylaş',
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'SmartFridge aileme katıl!\n\n'
                            'Davet kodu: $inviteCode',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Bu kodu aile üyelerinle paylaşabilirsin.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _leaveHousehold(creatingNew: true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add_home_work_outlined),
              label: const Text('Yeni Aile Kur'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _leaveHousehold(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Aileden Ayrıl'),
            ),
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
              hintText: 'Örn. ... Ailesi ',
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
