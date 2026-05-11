import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:easy_park/views/user/login_screen.dart';
import 'package:easy_park/services/auth_service.dart';
import 'package:easy_park/constants/api_config.dart';
import 'package:easy_park/services/local_db_service.dart';
import 'package:easy_park/views/user/face_enrollment_screen.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _nimNipCtrl    = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  String? _selectedGender;
  bool    _isLoading = false;
  String  _displayName  = 'User';
  String  _displayEmail = 'user@example.com';
  String? _profilePhotoUrl;
  String? _facePhotoUrl;

  static const _primary = Color(0xFF130160);
  static const _accent  = Color(0xFF4A3AFF);
  static const _soft    = Color(0xFFF5F4FF);

  final _genderOptions = [
    {'value': 'L', 'label': 'Laki-laki'},
    {'value': 'P', 'label': 'Perempuan'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _nimNipCtrl.dispose(); _addressCtrl.dispose(); _birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final saved = await LocalDbService.getLogin();
      if (saved != null) {
        final user = jsonDecode(saved['user_json'] as String);
        setState(() {
          _displayName     = user['name']  ?? 'User';
          _displayEmail    = user['email'] ?? 'user@example.com';
          _profilePhotoUrl = user['photo'];
          _facePhotoUrl    = user['face_photo'];
          _nameCtrl.text      = user['name']    ?? '';
          _emailCtrl.text     = user['email']   ?? '';
          _phoneCtrl.text     = user['phone']   ?? '';
          _nimNipCtrl.text    = user['nim_nip'] ?? '';
          _addressCtrl.text   = user['address'] ?? '';
          _selectedGender     = user['gender'];
          if (user['birth_date'] != null && user['birth_date'].isNotEmpty) {
            try {
              _birthDateCtrl.text = DateFormat('dd-MM-yyyy')
                  .format(DateTime.parse(user['birth_date']));
            } catch (_) {
              _birthDateCtrl.text = user['birth_date'];
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  String _buildPhotoUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    String p = path.replaceAll(RegExp(r'^/+'), '');
    if (p.startsWith('storage/')) p = p.substring(8);
    return '$baseUrl/storage/$p';
  }

  Future<void> _handleLogout() async {
    try {
      await LocalDbService.deleteLogin();
      if (mounted) {
        _snack('Logout berhasil');
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false);
      }
    } catch (e) {
      _snack('Gagal logout: $e', isError: true);
    }
  }

  Future<void> _selectDate() async {
    DateTime init = DateTime.now();
    if (_birthDateCtrl.text.isNotEmpty) {
      try {
        final p = _birthDateCtrl.text.split('-');
        if (p.length == 3) init = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      _birthDateCtrl.text = DateFormat('dd-MM-yyyy').format(picked);
    }
  }

  Future<void> _handleUpdate() async {
    final name      = _nameCtrl.text.trim();
    final email     = _emailCtrl.text.trim();
    final phone     = _phoneCtrl.text.trim();
    final nimNip    = _nimNipCtrl.text.trim();
    final address   = _addressCtrl.text.trim();
    final birthDate = _birthDateCtrl.text.trim();

    if (name.isEmpty)  { _snack('Nama tidak boleh kosong', isError: true); return; }
    if (email.isEmpty) { _snack('Email tidak boleh kosong', isError: true); return; }
    if (!RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(email)) {
      _snack('Format email tidak valid', isError: true); return;
    }

    String? backendBirth;
    if (birthDate.isNotEmpty) {
      try {
        final p = birthDate.split('-');
        backendBirth = '${p[2]}-${p[1]}-${p[0]}';
      } catch (_) {
        _snack('Format tanggal tidak valid', isError: true); return;
      }
    }

    setState(() => _isLoading = true);
    final result = await AuthService.updateProfile(
      name: name, email: email,
      phone: phone.isNotEmpty ? phone : null,
      nimNip: nimNip.isNotEmpty ? nimNip : null,
      gender: _selectedGender,
      birthDate: backendBirth,
      address: address.isNotEmpty ? address : null,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _displayName = name; _displayEmail = email;
          _profilePhotoUrl = result['user']?['photo'];
        }
      });
      _snack(result['message'] ?? 'Profil diperbarui', isError: result['success'] != true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, imageQuality: 70);
      if (f == null) return;
      setState(() => _isLoading = true);
      final result = await AuthService.uploadProfileImage(File(f.path));
      if (mounted) {
        setState(() => _isLoading = false);
        _snack(result['message'] ?? 'Upload selesai', isError: !result['success']);
        if (result['success'] == true) {
          final url = result['user']?['photo'] ?? result['photo'];
          if (url != null) setState(() => _profilePhotoUrl = url);
          await _loadUserData();
        }
      }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); _snack('Gagal: $e', isError: true); }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Ubah Foto Profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _primary)),
            const SizedBox(height: 16),
            _photoOption(Icons.camera_alt_rounded, 'Ambil dari Kamera', () {
              Navigator.pop(context); _pickImage(ImageSource.camera);
            }),
            const SizedBox(height: 10),
            _photoOption(Icons.photo_library_rounded, 'Pilih dari Galeri', () {
              Navigator.pop(context); _pickImage(ImageSource.gallery);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _photoOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _primary, size: 20),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFace = _facePhotoUrl != null && _facePhotoUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: Stack(children: [
        // ── Header background ──
        Container(
          height: MediaQuery.of(context).size.height * 0.38,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF130160), Color(0xFF3A1FA8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            Positioned(right: -40, top: -40,
                child: _circle(200, Colors.white.withOpacity(0.05))),
            Positioned(left: -20, bottom: 20,
                child: _circle(120, Colors.white.withOpacity(0.05))),
            Positioned(right: 60, top: 60,
                child: _circle(60, Colors.white.withOpacity(0.07))),
          ]),
        ),

        // ── Top buttons ──
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16, right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _topBtn(
                icon: Icons.logout_rounded,
                label: 'Keluar',
                onTap: _handleLogout,
              ),
              _topBtn(
                icon: hasFace ? Icons.face_rounded : Icons.face_retouching_off_rounded,
                label: hasFace ? 'Wajah ✓' : 'Daftarkan\nWajah',
                onTap: _isLoading ? null : () async {
                  final ok = await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()));
                  if (ok == true) await _loadUserData();
                },
                highlight: hasFace,
              ),
            ],
          ),
        ),

        SafeArea(child: Column(children: [
          // ── Avatar + name ──
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.32,
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: _isLoading ? null : _showPhotoOptions,
                  child: Stack(children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16, offset: const Offset(0, 6),
                        )],
                      ),
                      child: ClipOval(
                        child: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                            ? Image.network(_buildPhotoUrl(_profilePhotoUrl),
                                fit: BoxFit.cover, width: 96, height: 96,
                                errorBuilder: (_, __, ___) => _avatarPlaceholder())
                            : _avatarPlaceholder(),
                      ),
                    ),
                    Positioned(bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _accent, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(_displayName,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_displayEmail,
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
              ]),
            ),
          ),

          // ── Form card ──
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F7FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  // Section label
                  Row(children: [
                    Container(width: 4, height: 18,
                        decoration: BoxDecoration(color: _accent,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    const Text('Informasi Pribadi',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: _primary)),
                  ]),
                  const SizedBox(height: 16),

                  _field('Nama Lengkap', _nameCtrl, 'Masukkan nama',
                      icon: Icons.person_outline_rounded, required: true),
                  _field('Email', _emailCtrl, 'Masukkan email',
                      icon: Icons.email_outlined, required: true),
                  _field('No. Telepon', _phoneCtrl, '+62 812 3456 7890',
                      icon: Icons.phone_outlined),
                  _field('NIM / NIP', _nimNipCtrl, 'Masukkan NIM atau NIP',
                      icon: Icons.badge_outlined),

                  // Gender
                  _fieldWrapper('Jenis Kelamin', Icons.wc_rounded,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        hint: Text('Pilih jenis kelamin',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        items: _genderOptions.map((g) => DropdownMenuItem(
                          value: g['value'],
                          child: Text(g['label']!,
                              style: const TextStyle(fontSize: 14)),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedGender = v),
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ),

                  // Tanggal lahir
                  _fieldWrapper('Tanggal Lahir', Icons.cake_outlined,
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _birthDateCtrl,
                        decoration: InputDecoration(
                          hintText: '01-01-1990',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          border: InputBorder.none,
                          suffixIcon: Icon(Icons.calendar_today_rounded,
                              size: 16, color: Colors.grey.shade400),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  _field('Alamat', _addressCtrl, 'Masukkan alamat',
                      icon: Icons.location_on_outlined, maxLines: 2),

                  const SizedBox(height: 8),

                  // Save button
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: _primary.withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Row(mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Perbarui Profil',
                                    style: TextStyle(fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3)),
                              ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ])),

        // ── Loading overlay ──
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ]),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _avatarPlaceholder() => Container(
    color: _soft,
    padding: const EdgeInsets.all(20),
    child: SvgPicture.asset('assets/profile.svg', fit: BoxFit.cover),
  );

  Widget _topBtn({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool highlight = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? Colors.greenAccent.withOpacity(0.7)
              : Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            color: highlight ? Colors.greenAccent : Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: highlight ? Colors.greenAccent : Colors.white,
              fontSize: 12, fontWeight: FontWeight.w600, height: 1.2,
            )),
      ]),
    ),
  );

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    IconData? icon,
    bool required = false,
    int maxLines = 1,
  }) => _fieldWrapper(label, icon ?? Icons.edit_outlined,
    child: TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        suffixText: required ? ' *' : null,
        suffixStyle: const TextStyle(color: Colors.red, fontSize: 13),
      ),
      style: const TextStyle(fontSize: 14, color: Colors.black87),
    ),
  );

  Widget _fieldWrapper(
    String label,
    IconData icon, {
    required Widget child,
    VoidCallback? onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _soft, borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            const SizedBox(height: 4),
            child,
          ],
        )),
      ]),
    ),
  );
}