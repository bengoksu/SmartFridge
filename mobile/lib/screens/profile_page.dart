import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'edit_profile_page.dart';
import 'family_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final String username;

  const ProfilePage({super.key, required this.username});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  Map<String, dynamic> get _safeProfile =>
      _profile ??
      {
        'username': widget.username,
        'email': '',
        'first_name': '',
        'last_name': '',
        'avatar': null,
      };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiService.instance.get('/api/accounts/profile/');
      if (response.statusCode == 200) {
        final profile = jsonDecode(utf8.decode(response.bodyBytes));
        if (profile is Map<String, dynamic> && mounted) {
          setState(() => _profile = profile);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil bilgileri alınamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(profile: _safeProfile)),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  String? _avatarUrl() {
    final value = _safeProfile['avatar']?.toString();
    if (value == null || value.isEmpty) return null;
    return value.startsWith('http') ? value : '${ApiService.baseUrl}$value';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _safeProfile;
    final username = profile['username']?.toString() ?? widget.username;
    final email = profile['email']?.toString() ?? '';
    final fullName = [
      profile['first_name']?.toString() ?? '',
      profile['last_name']?.toString() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    final avatarUrl = _avatarUrl();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Profili düzenle',
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFDCFCE7),
                      backgroundImage: avatarUrl == null
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 52,
                              color: Color(0xFF22C55E),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    fullName.isEmpty ? username : fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (fullName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                  const SizedBox(height: 30),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Profili Düzenle'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _editProfile,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.family_restroom_rounded),
                    title: const Text('Ailem'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FamilyPage()),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Çıkış Yap',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
    );
  }
}
