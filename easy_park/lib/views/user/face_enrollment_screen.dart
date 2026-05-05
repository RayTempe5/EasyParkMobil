import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:easy_park/services/auth_service.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({Key? key}) : super(key: key);

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _isLoading = false;
  File? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    // Pakai kamera depan untuk face enrollment
    final frontCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() => _isCameraReady = true);
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final xFile = await _cameraController!.takePicture();
      setState(() => _capturedImage = File(xFile.path));
    } catch (e) {
      _showSnackBar('Gagal mengambil foto: $e', isError: true);
    }
  }

  Future<void> _submitFacePhoto() async {
    if (_capturedImage == null) return;

    setState(() => _isLoading = true);

    final result = await AuthService.uploadFacePhoto(_capturedImage!);

    if (mounted) {
      setState(() => _isLoading = false);
      _showSnackBar(
        result['message'] ?? 'Selesai',
        isError: !result['success'],
      );
      if (result['success']) {
        Navigator.pop(context, true); // return true = enrollment berhasil
      }
    }
  }

  void _retake() => setState(() => _capturedImage = null);

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Daftarkan Wajah'),
      ),
      body: _capturedImage != null
          ? _buildPreview()
          : _buildCamera(),
    );
  }

  Widget _buildCamera() {
    if (!_isCameraReady) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),

        // Overlay oval panduan wajah
        CustomPaint(painter: _FaceOvalPainter()),

        // Instruksi
        Positioned(
          top: 40,
          left: 0, right: 0,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Posisikan wajah di dalam oval\nPastikan pencahayaan cukup',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        // Tombol capture
        Positioned(
          bottom: 40,
          left: 0, right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white54, width: 4),
                ),
                child: const Icon(Icons.camera_alt, size: 32, color: Color(0xFF130160)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Image.file(_capturedImage!, fit: BoxFit.cover, width: double.infinity),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _retake,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Ulangi', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitFacePhoto,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_isLoading ? 'Menyimpan...' : 'Simpan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF130160),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Oval guide overlay
class _FaceOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.65,
      height: size.height * 0.45,
    );

    canvas.drawOval(ovalRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}