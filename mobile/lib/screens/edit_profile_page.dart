import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.profile['username']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.profile['email']?.toString() ?? '',
    );
    _firstNameController = TextEditingController(
      text: widget.profile['first_name']?.toString() ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.profile['last_name']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showMessage('Kullanıcı adı boş bırakılamaz.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await ApiService.instance.patchMultipart(
        '/api/accounts/profile/',
        fields: {
          'username': username,
          'email': _emailController.text.trim(),
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
        },
        fileBytes: _selectedImageBytes,
        fileName: _selectedImage?.name,
      );
      if (!mounted) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        Navigator.pop(context, data);
      } else {
        final detail = data is Map
            ? data.values.first.toString()
            : 'Profil güncellenemedi.';
        _showMessage(detail);
      }
    } catch (_) {
      _showMessage('Profil güncellenirken bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _currentAvatarUrl() {
    final value = widget.profile['avatar']?.toString();
    if (value == null || value.isEmpty) return null;
    return value.startsWith('http') ? value : '${ApiService.baseUrl}$value';
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatar = _currentAvatarUrl();
    final ImageProvider? avatarImage = _selectedImageBytes != null
        ? MemoryImage(_selectedImageBytes!)
        : currentAvatar != null
        ? NetworkImage(currentAvatar)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Profili Düzenle',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: const Color(0xFFDCFCE7),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 58,
                          color: Color(0xFF22C55E),
                        )
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: IconButton.filled(
                    tooltip: 'Fotoğraf seç',
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          _field(_usernameController, 'Kullanıcı adı', Icons.alternate_email),
          const SizedBox(height: 14),
          _field(
            _emailController,
            'E-posta',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _field(_firstNameController, 'Ad', Icons.person_outline),
          const SizedBox(height: 14),
          _field(_lastNameController, 'Soyad', Icons.person_outline),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSaving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
