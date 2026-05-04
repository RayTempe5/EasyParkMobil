import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:easy_park/services/vehicle_service.dart';
import 'package:easy_park/widgets/Bottom_Navigation.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  const VehicleRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState
    extends State<VehicleRegistrationScreen> {
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  int? _selectedBrandId;
  int? _selectedTypeId;
  int? _selectedModelId;

  File? _vehiclePhoto;
  File? _stnkPhoto;

  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _models = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVehicleTypes();
  }

  Future<void> _fetchVehicleTypes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final typeResult = await VehicleService.getVehicleTypes();
    setState(() {
      if (typeResult['success']) {
        _types = List<Map<String, dynamic>>.from(typeResult['data']);
      } else {
        _errorMessage = typeResult['message'];
      }
      _isLoading = false;
    });
  }

  Future<void> _fetchBrandsByType() async {
    setState(() {
      _brands = [];
      _models = [];
      _selectedBrandId = null;
      _selectedModelId = null;
      _modelController.clear();
      _isLoading = true;
    });

    if (_selectedTypeId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final brandResult =
        await VehicleService.getVehicleBrandsByType(_selectedTypeId!);
    setState(() {
      if (brandResult['success']) {
        _brands = List<Map<String, dynamic>>.from(brandResult['data']);
      } else {
        _errorMessage = brandResult['message'];
      }
      _isLoading = false;
    });
  }

  Future<void> _fetchModelsByBrand() async {
    setState(() {
      _models = [];
      _selectedModelId = null;
      _modelController.clear();
      _isLoading = true;
    });

    if (_selectedBrandId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final modelResult =
        await VehicleService.getVehicleModelsByBrand(_selectedBrandId!);
    setState(() {
      if (modelResult['success']) {
        _models = List<Map<String, dynamic>>.from(modelResult['data']);
      } else {
        _errorMessage = modelResult['message'];
      }
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source, bool isStnk) async {
    try {
      final XFile? selected = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (selected != null) {
        setState(() {
          if (isStnk) {
            _stnkPhoto = File(selected.path);
          } else {
            _vehiclePhoto = File(selected.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil gambar')),
        );
      }
    }
  }

  void _showImageSourceDialog(bool isStnk) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isStnk);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isStnk);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_plateController.text.isEmpty ||
        _selectedTypeId == null ||
        _selectedBrandId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap isi semua field wajib')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      const int vehicleLimit = 3;
      final vehicleCountResult = await VehicleService.getUserVehicleCount();
      if (!vehicleCountResult['success']) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vehicleCountResult['message'])),
          );
        }
        return;
      }

      final int currentCount = vehicleCountResult['data']['count'] ?? 0;
      if (currentCount >= vehicleLimit) {
        setState(() => _isLoading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 48),
              title: Text(
                'Batas Maksimal Tercapai',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700]),
              ),
              content: Text(
                'Anda sudah mencapai batas maksimal $vehicleLimit kendaraan. Silakan hapus salah satu terlebih dahulu.',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text('OK',
                      style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold)),
                ),
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      final modelName = _modelController.text.trim();
      if (modelName.isNotEmpty && _selectedModelId == null) {
        final existingModel = _models.firstWhere(
          (m) =>
              m['name'].toString().toLowerCase() == modelName.toLowerCase(),
          orElse: () => {},
        );

        if (existingModel.isNotEmpty) {
          _selectedModelId = existingModel['id'];
        } else {
          // ✅ hapus vehicleTypeId — tidak ada di migration
          final modelResult = await VehicleService.createVehicleModel(
            name: modelName,
            vehicleBrandId: _selectedBrandId!,
          );
          if (!modelResult['success']) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Gagal membuat model: ${modelResult['message']}')),
              );
            }
            return;
          }
          _selectedModelId = modelResult['data']['id'];
          setState(() => _models.add(modelResult['data']));
        }
      }

      final result = await VehicleService.addVehicle(
        vehicleTypeId: _selectedTypeId!,
        vehicleBrandId: _selectedBrandId!,
        vehicleModelId: _selectedModelId,
        plateNumber: _plateController.text,
        vehiclePhoto: _vehiclePhoto,
        stnkPhoto: _stnkPhoto,
      );

      setState(() => _isLoading = false);

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Kendaraan berhasil ditambahkan (${currentCount + 1}/$vehicleLimit)'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const BottomNavigationWidget(initialTab: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child:
                        Text(_errorMessage!, textAlign: TextAlign.center))
                : Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 7),
                        const Text(
                          'Kendaraan',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Silahkan input informasi kendaraan anda',
                          style: TextStyle(fontSize: 13, color: Colors.red),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                buildTextField('No Plat', _plateController,
                                    hint: 'P3333'),
                                buildDropdown(
                                  'Tipe',
                                  _types
                                      .map((t) => t['name'].toString())
                                      .toList(),
                                  _selectedTypeId != null
                                      ? _types
                                          .firstWhere(
                                            (t) => t['id'] == _selectedTypeId,
                                            orElse: () => {'name': null},
                                          )['name']
                                      : null,
                                  (value) {
                                    setState(() {
                                      _selectedTypeId = value != null
                                          ? _types.firstWhere(
                                              (t) => t['name'] == value)['id']
                                          : null;
                                    });
                                    _fetchBrandsByType();
                                  },
                                  hint: 'Pilih Tipe',
                                ),
                                buildDropdown(
                                  'Merk',
                                  _brands
                                      .map((b) => b['name'].toString())
                                      .toList(),
                                  _selectedBrandId != null
                                      ? _brands
                                          .firstWhere(
                                            (b) => b['id'] == _selectedBrandId,
                                            orElse: () => {'name': null},
                                          )['name']
                                      : null,
                                  (value) {
                                    setState(() {
                                      _selectedBrandId = value != null
                                          ? _brands.firstWhere(
                                              (b) => b['name'] == value)['id']
                                          : null;
                                    });
                                    _fetchModelsByBrand();
                                  },
                                  hint: 'Pilih Merk',
                                ),
                                buildAutocompleteTextField(
                                  'Model',
                                  _modelController,
                                  _models,
                                  hint: 'Masukkan Model',
                                ),
                                _buildImagePicker(
                                  label: 'Foto Kendaraan',
                                  currentFile: _vehiclePhoto,
                                  onTap: () =>
                                      _showImageSourceDialog(false),
                                  onRemove: () =>
                                      setState(() => _vehiclePhoto = null),
                                ),
                                _buildImagePicker(
                                  label: 'Foto STNK',
                                  currentFile: _stnkPhoto,
                                  onTap: () => _showImageSourceDialog(true),
                                  onRemove: () =>
                                      setState(() => _stnkPhoto = null),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _submitForm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.purple,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        side: const BorderSide(
                                            color: Colors.purple),
                                      ),
                                    ),
                                    child: const Text(
                                      'KONFIRMASI',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required File? currentFile,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration:
                BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: currentFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(currentFile, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onRemove,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : DashedRect(
                    color: Colors.grey.shade400,
                    gap: 5.0,
                    strokeWidth: 1.2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 30, color: Colors.grey.shade600),
                          const SizedBox(height: 10),
                          Text('Unggah $label',
                              style:
                                  const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 5),
                          Text(
                            'Tap untuk mengambil foto atau memilih dari galeri',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDropdown(String label, List<String> items,
      String? selectedItem, ValueChanged<String?> onChanged,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedItem,
            hint: Text(hint ?? 'Pilih',
                style: TextStyle(color: Colors.grey.shade600)),
            items: items
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAutocompleteTextField(String label,
      TextEditingController controller, List<Map<String, dynamic>> models,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const [];
              return models
                  .map((m) => m['name'].toString())
                  .where((option) => option
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (selection) {
              controller.text = selection;
              final selectedModel = models.firstWhere(
                  (m) => m['name'] == selection,
                  orElse: () => {'id': null});
              setState(() => _selectedModelId = selectedModel['id']);
            },
            fieldViewBuilder:
                (context, fieldController, focusNode, onFieldSubmitted) {
              fieldController.text = controller.text;
              return TextField(
                controller: fieldController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                ),
                onChanged: (value) {
                  controller.text = value;
                  setState(() => _selectedModelId = null);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class DashedRect extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double gap;

  const DashedRect({
    Key? key,
    required this.child,
    this.color = Colors.black,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
          color: color, strokeWidth: strokeWidth, gap: gap),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  _DashedRectPainter(
      {required this.color,
      required this.strokeWidth,
      required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;

    void drawDashedLine(
        double x1, double y1, double x2, double y2) {
      final dx = x2 - x1;
      final dy = y2 - y1;
      final distance = sqrt(dx * dx + dy * dy);
      final dashCount = distance / (dashWidth + gap);
      final dxStep = dx / dashCount;
      final dyStep = dy / dashCount;
      double x = x1, y = y1;
      for (int i = 0; i < dashCount; i++) {
        canvas.drawLine(Offset(x, y),
            Offset(x + dxStep * 0.5, y + dyStep * 0.5), paint);
        x += dxStep;
        y += dyStep;
      }
    }

    drawDashedLine(0, 0, size.width, 0);
    drawDashedLine(size.width, 0, size.width, size.height);
    drawDashedLine(size.width, size.height, 0, size.height);
    drawDashedLine(0, size.height, 0, 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}