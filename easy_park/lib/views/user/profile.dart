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

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Controllers — field names sesuai Laravel ProfileController
  final TextEditingController _nameController = TextEditingController();       // name
  final TextEditingController _emailController = TextEditingController();      // email
  final TextEditingController _phoneController = TextEditingController();      // phone
  final TextEditingController _nimNipController = TextEditingController();     // nim_nip
  final TextEditingController _addressController = TextEditingController();    // address
  final TextEditingController _birthDateController = TextEditingController();  // birth_date

  // Gender: 'L' atau 'P' — sesuai validasi Laravel 'in:L,P'
  String? _selectedGender;
  final List<Map<String, String>> _genderOptions = [
    {'value': 'L', 'label': 'Laki-laki'},
    {'value': 'P', 'label': 'Perempuan'},
  ];

  bool _isLoading = false;

  String _displayName = 'User';
  String _displayEmail = 'user@example.com';
  String? _profilePhotoUrl; // sesuai field 'photo' di Laravel

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final savedUser = await LocalDbService.getLogin();
      if (savedUser != null) {
        final user = jsonDecode(savedUser['user_json'] as String);

        setState(() {
          _displayName = user['name'] ?? 'User';
          _displayEmail = user['email'] ?? 'user@example.com';
          _profilePhotoUrl = user['photo']; // 'photo' sesuai Laravel

          _nameController.text = user['name'] ?? '';
          _emailController.text = user['email'] ?? '';
          _phoneController.text = user['phone'] ?? '';       // 'phone' bukan 'phone_number'
          _nimNipController.text = user['nim_nip'] ?? '';    // 'nim_nip' bukan 'nim'
          _addressController.text = user['address'] ?? '';
          _selectedGender = user['gender'];                  // 'L' atau 'P'

          // 'birth_date' bukan 'date_of_birth' — format dari backend: YYYY-MM-DD
          if (user['birth_date'] != null && user['birth_date'].isNotEmpty) {
            try {
              DateTime dateTime = DateTime.parse(user['birth_date']);
              _birthDateController.text = DateFormat('dd-MM-yyyy').format(dateTime);
            } catch (e) {
              _birthDateController.text = user['birth_date'];
              debugPrint('Error parsing birth_date: $e');
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  String _buildPhotoUrl(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) return '';
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      return photoPath;
    }
    String cleanPath = photoPath.replaceAll(RegExp(r'^/+'), '');
    if (cleanPath.startsWith('storage/')) {
      cleanPath = cleanPath.substring(8);
    }
    return '$baseUrl/storage/$cleanPath';
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await LocalDbService.deleteLogin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Logout berhasil'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal logout: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(email);
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    if (_birthDateController.text.isNotEmpty) {
      try {
        final parts = _birthDateController.text.split('-');
        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF130160)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _birthDateController.text = DateFormat('dd-MM-yyyy').format(picked);
    }
  }

  Future<void> _handleUpdateProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final nimNip = _nimNipController.text.trim();
    final address = _addressController.text.trim();
    final birthDate = _birthDateController.text.trim();

    // Validasi sesuai rules Laravel
    if (name.isEmpty) {
      _showSnackBar('Nama tidak boleh kosong', isError: true);
      return;
    }
    if (name.length > 255) {
      _showSnackBar('Nama maksimal 255 karakter', isError: true);
      return;
    }

    if (email.isEmpty) {
      _showSnackBar('Email tidak boleh kosong', isError: true);
      return;
    }
    if (!_isValidEmail(email)) {
      _showSnackBar('Format email tidak valid', isError: true);
      return;
    }

    // phone: max 20 karakter — sesuai Laravel 'max:20'
    if (phone.isNotEmpty) {
      if (!RegExp(r'^\+?[0-9]{8,20}$').hasMatch(phone)) {
        _showSnackBar('Nomor telepon harus 8-20 digit angka', isError: true);
        return;
      }
    }

    // nim_nip: max 50 karakter — sesuai Laravel 'max:50'
    if (nimNip.isNotEmpty && nimNip.length > 50) {
      _showSnackBar('NIM/NIP maksimal 50 karakter', isError: true);
      return;
    }

    // address: max 500 karakter — sesuai Laravel 'max:500'
    if (address.isNotEmpty && address.length > 500) {
      _showSnackBar('Alamat maksimal 500 karakter', isError: true);
      return;
    }

    // birth_date: validasi format DD-MM-YYYY
    String? backendBirthDate;
    if (birthDate.isNotEmpty) {
      try {
        final parts = birthDate.split('-');
        if (parts.length != 3) throw Exception('Invalid format');
        final date = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
        if (date.isAfter(DateTime.now()) || date.year < 1900) {
          throw Exception('Invalid date range');
        }
        // Konversi ke YYYY-MM-DD untuk backend
        backendBirthDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      } catch (e) {
        _showSnackBar('Format tanggal tidak valid (DD-MM-YYYY)', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.updateProfile(
        name: name,
        email: email,
        phone: phone.isNotEmpty ? phone : null,         // 'phone' bukan 'phone_number'
        nimNip: nimNip.isNotEmpty ? nimNip : null,       // 'nim_nip' bukan 'nim'
        gender: _selectedGender,                         // 'L' atau 'P'
        birthDate: backendBirthDate,                     // 'birth_date' bukan 'date_of_birth'
        address: address.isNotEmpty ? address : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success']) {
            _displayName = name;
            _displayEmail = email;
            _profilePhotoUrl = result['user']['photo']; // 'photo' bukan 'image'
          }
        });

        _showSnackBar(
          result['message'] ?? 'Profil berhasil diperbarui',
          isError: !result['success'],
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        setState(() => _isLoading = true);

        // Upload sebagai 'photo' — sesuai validasi Laravel 'mimes:jpg,jpeg,png' 'max:2048'
        final result = await AuthService.uploadProfileImage(imageFile);

        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar(
            result['message'] ?? 'Proses upload selesai',
            isError: !result['success'],
          );

          if (result['success']) {
            // Ambil 'photo' bukan 'image'
            final String? newPhotoUrl =
                result['user']?['photo'] ?? result['photo'];

            if (newPhotoUrl != null) {
              final savedUser = await LocalDbService.getLogin();
              if (savedUser != null) {
                final user = jsonDecode(savedUser['user_json'] as String);
                user['photo'] = newPhotoUrl; // simpan sebagai 'photo'
                await LocalDbService.saveLogin(
                  email: savedUser['email'] as String,
                  token: savedUser['token'] as String,
                  role: savedUser['role'] as String,
                  userJson: jsonEncode(user),
                );
                setState(() => _profilePhotoUrl = newPhotoUrl);
              }
            } else {
              await _loadUserData();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal upload foto: $e', isError: true);
      }
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pilih Sumber Foto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF130160),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF130160).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_camera, color: Color(0xFF130160)),
                  ),
                  title: const Text('Ambil dari Kamera',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF130160).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library, color: Color(0xFF130160)),
                  ),
                  title: const Text('Pilih dari Galeri',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF130160), Color(0xFF2D1B89)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: TextButton.icon(
                onPressed: () async => await _handleLogout(context),
                icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                label: const Text('Log out',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isLoading ? null : _showImageSourceOptions,
                        child: Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                                    ? Image.network(
                                        _buildPhotoUrl(_profilePhotoUrl),
                                        fit: BoxFit.cover,
                                        width: 90,
                                        height: 90,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF130160)),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            padding: const EdgeInsets.all(20),
                                            child: SvgPicture.asset('assets/profile.svg', fit: BoxFit.cover),
                                          );
                                        },
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(20),
                                        child: SvgPicture.asset('assets/profile.svg', fit: BoxFit.cover),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF130160),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _displayEmail,
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _showImageSourceOptions,
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Edit foto profil',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ListView(
                        children: [
                          // name — required di Laravel
                          _buildTextField('Nama', _nameController, 'Masukkan nama', required: true),
                          const SizedBox(height: 20),

                          // email — required di Laravel
                          _buildTextField('Email', _emailController, 'Masukkan email', required: true),
                          const SizedBox(height: 20),

                          // phone — nullable, max:20
                          _buildTextField('No Telepon', _phoneController, '+62 812 3456 7890'),
                          const SizedBox(height: 20),

                          // nim_nip — nullable, max:50, unique
                          _buildTextField('NIM / NIP', _nimNipController, 'Masukkan NIM atau NIP'),
                          const SizedBox(height: 20),

                          // gender — nullable, in:L,P
                          _buildGenderField(),
                          const SizedBox(height: 20),

                          // birth_date — nullable, date (YYYY-MM-DD ke backend)
                          _buildDateField('Tanggal Lahir', _birthDateController, '01-01-1990'),
                          const SizedBox(height: 20),

                          // address — nullable, max:500
                          _buildTextField('Alamat', _addressController, 'Masukkan alamat'),
                          const SizedBox(height: 30),

                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF130160), Color(0xFF2D1B89)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF130160).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleUpdateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'PERBARUI PROFIL',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hintText, {
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black)),
            if (required)
              const Text(' *', style: TextStyle(color: Colors.red, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF130160)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  // Gender dropdown — sesuai validasi Laravel 'in:L,P'
  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Jenis Kelamin',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          hint: const Text('Pilih jenis kelamin'),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF130160)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: _genderOptions.map((g) {
            return DropdownMenuItem<String>(
              value: g['value'],
              child: Text(g['label']!),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedGender = value),
        ),
      ],
    );
  }

  Widget _buildDateField(
      String label, TextEditingController controller, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                suffixIcon: const Icon(Icons.calendar_today,
                    color: Color(0xFF130160), size: 20),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF130160), width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}