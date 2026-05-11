import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'kendaraan_Add.dart';
import 'package:easy_park/services/vehicle_service.dart';
import 'package:easy_park/constants/api_config.dart';
import 'package:easy_park/services/selected_vehicle.dart';
import 'package:easy_park/widgets/Bottom_Navigation.dart';
import 'kendaraan_Edit.dart';

class KendaraanScreen extends StatefulWidget {
  const KendaraanScreen({Key? key}) : super(key: key);
  @override
  State<KendaraanScreen> createState() => _KendaraanScreenState();
}

class _KendaraanScreenState extends State<KendaraanScreen> {
  List<Map<String, dynamic>> vehicles = [];
  bool isLoading = true;
  String? errorMessage;
  int? selectedVehicleId;

  static const _primary = Color(0xFF1A1A4B);
  static const _accent  = Color(0xFF4A3AFF);
  static const _soft    = Color(0xFFF0EFFF);

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    final sel = SelectedVehicle().vehicle;
    if (sel != null) selectedVehicleId = sel['id'];
  }

  Future<void> _fetchVehicles() async {
    setState(() { isLoading = true; errorMessage = null; });
    final result = await VehicleService.getVehicles();
    if (result['success']) {
      setState(() {
        vehicles = List<Map<String, dynamic>>.from(result['vehicles']);
        isLoading = false;
      });
    } else {
      setState(() { isLoading = false; errorMessage = result['message']; });
    }
  }

  Future<void> _deleteVehicle(int id, String name) async {
    final sel = SelectedVehicle();
    if (sel.vehicle?['id'] == id) await sel.clearSelectedVehicle();
    final result = await VehicleService.deleteVehicle(id);
    if (result['success']) {
      await _fetchVehicles();
      if (mounted) _snack('Kendaraan $name dihapus');
    } else {
      if (mounted) _snack(result['message'], isError: true);
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

  void _confirmDelete(int id, String name, String plate) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.delete_outline_rounded,
                color: Colors.red.shade400, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Hapus Kendaraan',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                  color: _primary)),
          const SizedBox(height: 8),
          Text('$name · $plate akan dihapus dari akun Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600,
                  height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('Batal',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteVehicle(id, name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Hapus',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: _primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text('Kendaraan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, Color(0xFF3A2EA8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(right: -30, top: -30,
                      child: _circle(160, Colors.white.withOpacity(0.06))),
                  Positioned(right: 80, bottom: 10,
                      child: _circle(60, Colors.white.withOpacity(0.06))),
                ]),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const VehicleRegistrationScreen()));
                    await _fetchVehicles();
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Tambah',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),

          // ── Hint banner ──
          SliverToBoxAdapter(
            child: Container(
              color: _primary,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F7FF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Pilih satu kendaraan yang sedang digunakan',
                      style: TextStyle(fontSize: 12,
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
              ),
            ),
          ),

          // ── Content ──
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _accent)),
            )
          else if (errorMessage != null)
            SliverFillRemaining(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchVehicles,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )),
            )
          else if (vehicles.isEmpty)
            SliverFillRemaining(
              child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: _soft, shape: BoxShape.circle),
                    child: const Icon(Icons.directions_car_outlined,
                        size: 40, color: _accent),
                  ),
                  const SizedBox(height: 16),
                  const Text('Belum ada kendaraan',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w600, color: _primary)),
                  const SizedBox(height: 6),
                  Text('Tambah kendaraan untuk mulai parkir',
                      style: TextStyle(fontSize: 13,
                          color: Colors.grey.shade500)),
                ],
              )),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildCard(vehicles[i]),
                  childCount: vehicles.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> vehicle) {
    final id         = vehicle['id'] as int;
    final typeName   = vehicle['type']?['name']  ?? '-';
    final brandName  = vehicle['brand']?['name'] ?? '-';
    final modelName  = vehicle['model']?['name'] ?? '-';
    final plate      = vehicle['plate_number']   ?? '-';
    final photoPath  = vehicle['vehicle_photo']  ?? '';
    final photoUrl   = photoPath.isNotEmpty
        ? '$baseUrl/storage/$photoPath' : '';
    final isSelected = selectedVehicleId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? _accent.withOpacity(0.4) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? _accent.withOpacity(0.12)
                : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: [
        // ── Top row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
          child: Row(children: [
            // Icon / photo
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: isSelected ? _accent.withOpacity(0.1) : _soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: photoUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _carIcon(isSelected)),
                    )
                  : _carIcon(isSelected),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(modelName,
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700, color: _primary),
                      overflow: TextOverflow.ellipsis)),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text('Aktif',
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text('$brandName · $typeName',
                    style: TextStyle(fontSize: 12,
                        color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(plate,
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5)),
                ),
              ],
            )),

            // Delete
            IconButton(
              onPressed: () => _confirmDelete(id, modelName, plate),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
              splashRadius: 20,
            ),
          ]),
        ),

        // Divider
        Divider(height: 1, color: Colors.grey.shade100),

        // ── Buttons ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(children: [
            Expanded(child: _cardBtn(
              label: 'Edit',
              icon: Icons.edit_rounded,
              onTap: () async {
                final result = await Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => VehicleEditScreen(vehicle: vehicle)));
                await _fetchVehicles();
                if (result != null && mounted) {
                  final sel = SelectedVehicle();
                  if (sel.vehicle?['id'] == result['id']) {
                    await sel.setSelectedVehicle(photoUrl, result);
                  }
                  _snack('Kendaraan diperbarui: ${result['plate_number']}');
                }
              },
            )),
            const SizedBox(width: 10),
            Expanded(child: _cardBtn(
              label: isSelected ? 'Terpilih' : 'Pilih',
              icon: isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              filled: true,
              selected: isSelected,
              onTap: isSelected ? null : () async {
                await SelectedVehicle().setSelectedVehicle(photoUrl, vehicle);
                setState(() => selectedVehicleId = id);
                _snack('Kendaraan dipilih: $modelName');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const BottomNavigationWidget()),
                  (_) => false,
                );
              },
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _cardBtn({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    bool filled = false,
    bool selected = false,
  }) {
    final color = selected ? Colors.green : _accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled
              ? (selected ? Colors.green.shade50 : _soft)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled
                ? (selected ? Colors.green.shade200 : _accent.withOpacity(0.3))
                : Colors.grey.shade200,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 15,
              color: filled ? color : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: filled ? color : Colors.grey.shade700,
              )),
        ]),
      ),
    );
  }

  Widget _carIcon(bool active) => Icon(
    Icons.directions_car_rounded,
    size: 24,
    color: active ? _accent : Colors.grey.shade400,
  );

  Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}