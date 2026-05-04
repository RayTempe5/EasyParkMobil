import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:easy_park/constants/api_config.dart';
import 'package:easy_park/services/local_db_service.dart';
import 'package:http_parser/http_parser.dart';

class VehicleService {

  static Future<String?> _getToken() async {
    final savedUser = await LocalDbService.getLogin();
    return savedUser?['token'] as String?;
  }

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  static Map<String, dynamic> _noToken() => {
    'success': false,
    'message': 'Token tidak ditemukan. Silakan login ulang.',
  };

  static Map<String, dynamic> _error(Map<String, dynamic> body) => {
    'success': false,
    'message': body['message'] ?? 'Terjadi kesalahan.',
    'errors': body['errors'] ?? {},
  };

  static Map<String, dynamic> _exception(dynamic e) => {
    'success': false,
    'message': 'Error: $e',
  };

  static Future<Map<String, dynamic>> getVehicles() async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final response = await http.get(
        Uri.parse('$apiBaseUrl/vehicles'),
        headers: _headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'vehicles': body['vehicles']};
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  static Future<Map<String, dynamic>> getVehicle(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final response = await http.get(
        Uri.parse('$apiBaseUrl/vehicles/$id'),
        headers: _headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'vehicle': body['vehicle']};
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  static Future<Map<String, dynamic>> addVehicle({
    required int vehicleTypeId,
    required int vehicleBrandId,
    int? vehicleModelId,
    required String plateNumber,
    String? color,
    File? vehiclePhoto,
    File? stnkPhoto,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/vehicles'),
      );

      request.headers.addAll(_headers(token));
      request.fields['vehicle_type_id'] = vehicleTypeId.toString();
      request.fields['vehicle_brand_id'] = vehicleBrandId.toString();
      if (vehicleModelId != null) {
        request.fields['vehicle_model_id'] = vehicleModelId.toString();
      }
      request.fields['plate_number'] = plateNumber.toUpperCase();
      if (color != null) request.fields['color'] = color;

      if (vehiclePhoto != null) {
        final ext = vehiclePhoto.path.split('.').last.toLowerCase();
        request.files.add(await http.MultipartFile.fromPath(
          'vehicle_photo',
          vehiclePhoto.path,
          contentType: MediaType('image', ext == 'jpg' ? 'jpeg' : ext),
        ));
      }

      if (stnkPhoto != null) {
        final ext = stnkPhoto.path.split('.').last.toLowerCase();
        request.files.add(await http.MultipartFile.fromPath(
          'stnk_photo',
          stnkPhoto.path,
          contentType: MediaType('image', ext == 'jpg' ? 'jpeg' : ext),
        ));
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final body = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Kendaraan berhasil ditambahkan.',
          'vehicle': body['vehicle'],
        };
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  static Future<Map<String, dynamic>> updateVehicle({
    required int vehicleId,
    required int vehicleTypeId,
    required int vehicleBrandId,
    int? vehicleModelId,
    required String plateNumber,
    String? color,
    File? vehiclePhoto,
    File? stnkPhoto,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/vehicles/$vehicleId'),
      );

      request.headers.addAll(_headers(token));
      request.fields['vehicle_type_id'] = vehicleTypeId.toString();
      request.fields['vehicle_brand_id'] = vehicleBrandId.toString();
      if (vehicleModelId != null) {
        request.fields['vehicle_model_id'] = vehicleModelId.toString();
      }
      request.fields['plate_number'] = plateNumber.toUpperCase();
      if (color != null) request.fields['color'] = color;

      if (vehiclePhoto != null) {
        final ext = vehiclePhoto.path.split('.').last.toLowerCase();
        request.files.add(await http.MultipartFile.fromPath(
          'vehicle_photo',
          vehiclePhoto.path,
          contentType: MediaType('image', ext == 'jpg' ? 'jpeg' : ext),
        ));
      }

      if (stnkPhoto != null) {
        final ext = stnkPhoto.path.split('.').last.toLowerCase();
        request.files.add(await http.MultipartFile.fromPath(
          'stnk_photo',
          stnkPhoto.path,
          contentType: MediaType('image', ext == 'jpg' ? 'jpeg' : ext),
        ));
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final body = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Kendaraan berhasil diperbarui.',
          'vehicle': body['vehicle'],
        };
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  static Future<Map<String, dynamic>> deleteVehicle(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/vehicles/$id'),
        headers: _headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Kendaraan berhasil dihapus.',
        };
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  static Future<Map<String, dynamic>> getVehicleTypes() async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final response = await http.get(
        Uri.parse('$apiBaseUrl/vehicle-types'),
        headers: _headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': body['data']};
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  // vehicle_brands tidak punya vehicle_type_id — kembalikan semua brand
  static Future<Map<String, dynamic>> getVehicleBrandsByType(int typeId) async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final response = await http.get(
        Uri.parse('$apiBaseUrl/vehicle-brands/by-type/$typeId'),
        headers: _headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': body['data']};
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  static Future<Map<String, dynamic>> getVehicleModelsByBrand(int brandId) async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final response = await http.get(
        Uri.parse('$apiBaseUrl/vehicle-models/by-brand/$brandId'),
        headers: _headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': body['data']};
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  // vehicle_models tidak punya vehicle_type_id — hapus parameter vehicleTypeId
  static Future<Map<String, dynamic>> createVehicleModel({
    required String name,
    required int vehicleBrandId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return _noToken();

      final response = await http.post(
        Uri.parse('$apiBaseUrl/vehicle-models'),
        headers: {
          ..._headers(token),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'vehicle_brand_id': vehicleBrandId,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Model berhasil dibuat.',
          'data': body['data'] ?? body,
        };
      } else {
        return _error(body);
      }
    } catch (e) {
      return _exception(e);
    }
  }

  static Future<Map<String, dynamic>> getUserVehicleCount() async {
    try {
      final result = await getVehicles();
      if (result['success']) {
        final List<dynamic> vehicles = result['vehicles'] ?? [];
        return {
          'success': true,
          'data': {'count': vehicles.length},
        };
      } else {
        return result;
      }
    } catch (e) {
      return _exception(e);
    }
  }
}