import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:easy_park/constants/api_config.dart';
import 'local_db_service.dart';
import 'selected_vehicle.dart';

class AuthService {
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String nimNip,     // 'nim_nip' sesuai User model
    required String phone,      // 'phone' bukan 'phone_number'
    required String gender,     // 'gender' — in:L,P
    required String birthDate,  // 'birth_date' bukan 'date_of_birth'
    required String address,
  }) async {
    final url = Uri.parse('$apiBaseUrl/register');

    try {
      final response = await http.post(
        url,
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'nim_nip': nimNip,      // sesuai $fillable User model
          'phone': phone,          // sesuai $fillable User model
          'gender': gender,        // sesuai $fillable User model
          'birth_date': birthDate, // sesuai $fillable User model
          'address': address,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Registrasi berhasil',
          'token': body['token'],  // 'token' bukan 'access_token' sesuai AuthController
          'user': body['user'],
          'redirect_to': body['redirect_to'] ?? '',
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Gagal registrasi',
          'errors': body['errors'] ?? {},
        };
      }
    } catch (e) {
      debugPrint('Error registering: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan saat menghubungi server.',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      debugPrint('API login response: ${response.body}');
      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = result['user'];
        final token = result['token']; // ✅ 'token' bukan 'access_token'
        final role = user['role'];     // string name dari role relationship
        final redirectTo = _mapRoleToRedirect(role);

        await SelectedVehicle().clearSelectedVehicle();

        await LocalDbService.saveLogin(
          email: user['email'],
          token: token,
          role: role,
          userJson: jsonEncode(user),
        );

        return {
          'success': true,
          'message': result['message'] ?? 'Login berhasil',
          'token': token,
          'user': user,
          'role': role,
          'redirect_to': redirectTo,
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Login gagal',
          'errors': result['errors'] ?? {},
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<void> logout() async {
    try {
      final savedUser = await LocalDbService.getLogin();
      final token = savedUser?['token'] as String?;
      if (token != null) {
        await http.post(
          Uri.parse('$apiBaseUrl/logout'), // POST /api/logout sesuai routes
          headers: {
            'ngrok-skip-browser-warning': 'true',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      }
      await LocalDbService.deleteLogin();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  static Future<Map<String, dynamic>> autoLogin() async {
    try {
      final savedUser = await LocalDbService.getLogin();
      debugPrint('Saved user from LocalDbService: $savedUser');
      if (savedUser == null) {
        return {'success': false, 'message': 'No user data found'};
      }

      final email = savedUser['email'] as String?;
      final token = savedUser['token'] as String?;
      final userJson = savedUser['user_json'] as String?;
      if (email == null || token == null || userJson == null) {
        await LocalDbService.deleteLogin();
        return {
          'success': false,
          'message': 'Incomplete user data in LocalDbService'
        };
      }

      final storedUser = jsonDecode(userJson);
      final storedRole = storedUser['role'];

      // ✅ '/me' bukan '/user' — sesuai routes api.php
      final response = await http.get(
        Uri.parse('$apiBaseUrl/me'),
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        return http.Response('Request timed out', 504);
      });

      debugPrint('API me response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // ✅ Response /me: { success: true, user: {...} }
        final user = result['user'];
        if (user == null) {
          await LocalDbService.deleteLogin();
          return {'success': false, 'message': 'Invalid user data from API'};
        }

        // role dari /me adalah object karena load('role')
        // ambil name dari role object atau langsung string
        final roleData = user['role'];
        final role = roleData is Map ? roleData['name'] : roleData ?? storedRole;

        if (role == null) {
          await LocalDbService.deleteLogin();
          return {'success': false, 'message': 'No role found in user data'};
        }

        await LocalDbService.saveLogin(
          email: email,
          token: token,
          role: role,
          userJson: jsonEncode(user),
        );

        return {
          'success': true,
          'message': 'Auto-login successful',
          'token': token,
          'user': user,
          'role': role,
          'redirect_to': _mapRoleToRedirect(role),
        };
      } else {
        if (storedRole != null) {
          return {
            'success': true,
            'message': 'Auto-login using stored data',
            'token': token,
            'user': storedUser,
            'role': storedRole,
            'redirect_to': _mapRoleToRedirect(storedRole),
          };
        }

        await LocalDbService.deleteLogin();
        return {
          'success': false,
          'message': 'Invalid or expired token: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
      await LocalDbService.deleteLogin();
      return {
        'success': false,
        'message': 'Auto-login failed: $e',
      };
    }
  }

  // ✅ Sesuai ProfileController + User model $fillable
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,      // 'phone' sesuai $fillable
    String? nimNip,     // 'nim_nip' sesuai $fillable
    String? gender,     // 'gender' sesuai $fillable — in:L,P
    String? birthDate,  // 'birth_date' sesuai $fillable + cast 'date'
    String? address,
  }) async {
    // ✅ '/profile/update' sesuai routes api.php
    final url = Uri.parse('$apiBaseUrl/profile/update');

    try {
      final savedUser = await LocalDbService.getLogin();
      final token = savedUser?['token'] as String?;
      if (token == null) {
        return {
          'success': false,
          'message': 'Tidak ada token ditemukan. Silakan login ulang.',
        };
      }

      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;
      if (nimNip != null) data['nim_nip'] = nimNip;
      if (gender != null) data['gender'] = gender;
      if (birthDate != null) data['birth_date'] = birthDate;
      if (address != null) data['address'] = address;

      final response = await http.post( // ✅ POST sesuai routes
        url,
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      final body = jsonDecode(response.body);
      debugPrint('Update profile response: $body');

      if (response.statusCode == 200) {
        if (body['user'] != null) {
          final userObj = body['user'];
          // role dari ProfileController response adalah object (load('role'))
          final roleData = userObj['role'];
          final role = roleData is Map
              ? roleData['name']
              : savedUser?['role'] ?? 'mahasiswa';

          await LocalDbService.saveLogin(
            email: userObj['email'] ?? savedUser?['email'] ?? '',
            token: token,
            role: role,
            userJson: jsonEncode(userObj),
          );
        }

        return {
          'success': true,
          'message': body['message'] ?? 'Profil berhasil diperbarui',
          'user': body['user'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Gagal memperbarui profil',
          'errors': body['errors'] ?? {},
        };
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan saat memperbarui profil.',
        'error': e.toString(),
      };
    }
  }

  // ✅ Upload photo via /profile/update dengan multipart
  // Tidak ada endpoint terpisah di routes — pakai profile/update
  static Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    debugPrint('Starting profile image upload...');
    final url = Uri.parse('$apiBaseUrl/profile/update');

    try {
      final savedUser = await LocalDbService.getLogin();
      final token = savedUser?['token'] as String?;
      if (token == null) {
        return {
          'success': false,
          'message': 'Tidak ada token ditemukan. Silakan login ulang.',
        };
      }

      // Ambil data user dari local storage
      final userJson = savedUser?['user_json'] as String?;
      final userData = userJson != null ? jsonDecode(userJson) : {};

      // Validasi name & email tersedia
      final userName = userData['name'] as String? ?? '';
      final userEmail = userData['email'] as String? ?? '';
      if (userName.isEmpty || userEmail.isEmpty) {
        return {
          'success': false,
          'message': 'Data user tidak lengkap. Silakan login ulang.',
        };
      }

      // max:2048 KB = 2MB sesuai validasi ProfileController
      final fileSize = await imageFile.length();
      if (fileSize > 2 * 1024 * 1024) {
        return {
          'success': false,
          'message': 'Ukuran file terlalu besar (maksimum 2MB).',
        };
      }

      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        })
        // ✅ Field wajib sesuai validasi Laravel (required)
        ..fields['name'] = userName
        ..fields['email'] = userEmail
        ..files.add(
          await http.MultipartFile.fromPath(
            'photo',
            imageFile.path,
            filename: path.basename(imageFile.path),
          ),
        );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      debugPrint('Response status: ${streamedResponse.statusCode}');
      debugPrint('Response body: $responseBody');

      final body = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final String? photoUrl = body['user']?['photo'] ?? body['photo'];
        debugPrint('Extracted photo URL: $photoUrl');

        if (body['user'] != null) {
          final userObj = body['user'];
          final roleData = userObj['role'];
          final role = roleData is Map
              ? roleData['name']
              : savedUser?['role'] ?? 'mahasiswa';

          await LocalDbService.saveLogin(
            email: userObj['email'] ?? savedUser?['email'] ?? '',
            token: token,
            role: role,
            userJson: jsonEncode(userObj),
          );
        } else if (photoUrl != null) {
          final currentUserJson = savedUser?['user_json'] as String?;
          if (currentUserJson != null) {
            final user = jsonDecode(currentUserJson);
            user['photo'] = photoUrl;
            await LocalDbService.saveLogin(
              email: savedUser?['email'] ?? '',
              token: token,
              role: savedUser?['role'] ?? 'mahasiswa',
              userJson: jsonEncode(user),
            );
          }
        }

        return {
          'success': true,
          'message': body['message'] ?? 'Foto berhasil diupload',
          'user': body['user'],
          'photo': photoUrl,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Gagal upload foto',
          'errors': body['errors'] ?? {},
        };
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan saat upload foto.',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> uploadFacePhoto(File imageFile) async {
  final url = Uri.parse('$apiBaseUrl/profile/face');

  try {
    final savedUser = await LocalDbService.getLogin();
    final token = savedUser?['token'] as String?;
    if (token == null) {
      return {'success': false, 'message': 'Tidak ada token. Silakan login ulang.'};
    }

    final fileSize = await imageFile.length();
    if (fileSize > 5 * 1024 * 1024) {
      return {'success': false, 'message': 'Ukuran file terlalu besar (maksimum 5MB).'};
    }

    final request = http.MultipartRequest('POST', url)
      ..headers.addAll({
        'ngrok-skip-browser-warning': 'true',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      })
      ..files.add(await http.MultipartFile.fromPath(
        'face_photo',
        imageFile.path,
        filename: path.basename(imageFile.path),
      ));

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();
    final body = jsonDecode(responseBody);

    debugPrint('Face upload status: ${streamedResponse.statusCode}');
    debugPrint('Face upload body: $responseBody');

    if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
      if (body['user'] != null) {
        final userObj = body['user'];
        final roleData = userObj['role'];
        final role = roleData is Map ? roleData['name'] : savedUser?['role'] ?? 'mahasiswa';
        await LocalDbService.saveLogin(
          email: userObj['email'] ?? savedUser?['email'] ?? '',
          token: token,
          role: role,
          userJson: jsonEncode(userObj),
        );
      }
      return {
        'success': true,
        'message': body['message'] ?? 'Wajah berhasil didaftarkan',
        'user': body['user'],
      };
    } else {
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal mendaftarkan wajah',
        'errors': body['errors'] ?? {},
      };
    }
  } catch (e) {
    debugPrint('Error uploading face: $e');
    return {'success': false, 'message': 'Terjadi kesalahan saat upload wajah.'};
  }
}

  static Future<Map<String, dynamic>> getProfile() async {
    // ✅ GET /profile sesuai routes
    final url = Uri.parse('$apiBaseUrl/profile');

    try {
      final savedUser = await LocalDbService.getLogin();
      final token = savedUser?['token'] as String?;
      if (token == null) {
        return {
          'success': false,
          'message': 'Tidak ada token ditemukan. Silakan login ulang.',
        };
      }

      final response = await http.get(
        url,
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = jsonDecode(response.body);
      debugPrint('Get profile response: $body');

      if (response.statusCode == 200) {
        if (body['user'] != null) {
          final userObj = body['user'];
          final roleData = userObj['role'];
          final role = roleData is Map
              ? roleData['name']
              : savedUser?['role'] ?? 'mahasiswa';

          await LocalDbService.saveLogin(
            email: userObj['email'] ?? savedUser?['email'] ?? '',
            token: token,
            role: role,
            userJson: jsonEncode(userObj),
          );
        }

        return {
          'success': true,
          'message': body['message'] ?? 'Profil berhasil diambil',
          'user': body['user'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Gagal mengambil profil',
          'errors': body['errors'] ?? {},
        };
      }
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan saat mengambil profil.',
        'error': e.toString(),
      };
    }
  }

  static String _mapRoleToRedirect(String role) {
    switch (role.toLowerCase()) {
      case 'mahasiswa':
        return 'Bottom_Navigation';
      case 'petugas':
        return 'petugasHome';
      case 'admin':
        return 'adminHome';
      default:
        return 'login';
    }
  }
}