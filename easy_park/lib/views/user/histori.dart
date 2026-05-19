import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:easy_park/constants/api_config.dart';
import 'package:easy_park/services/local_db_service.dart';

class ParkingRecord {
  final String vehicle;
  final String time;
  final String status;
  final String plate;
  final DateTime dateTime;

  ParkingRecord({
    required this.vehicle,
    required this.time,
    required this.status,
    required this.plate,
    required this.dateTime,
  });

  factory ParkingRecord.fromRawJsonEntry(Map<String, dynamic> json) {
    String rawTime = json['entry_time'] ?? '';
    String formattedTime = '';
    DateTime dateTime = DateTime.now();

    if (rawTime.isNotEmpty) {
      try {
        dateTime = DateTime.parse(rawTime).toLocal();
        formattedTime = DateFormat('HH:mm', 'id_ID').format(dateTime);
      } catch (e) {
        formattedTime = '';
      }
    }

    return ParkingRecord(
      vehicle: json['vehicle_type_name'] ?? '-',
      time: formattedTime,
      status: 'Masuk',
      plate: json['plate_number'] ?? '',
      dateTime: dateTime,
    );
  }

  factory ParkingRecord.fromRawJsonExit(Map<String, dynamic> json) {
    String rawTime = json['exit_time'] ?? '';
    String formattedTime = '';
    DateTime dateTime = DateTime.now();

    if (rawTime.isNotEmpty) {
      try {
        dateTime = DateTime.parse(rawTime).toLocal();
        formattedTime = DateFormat('HH:mm', 'id_ID').format(dateTime);
      } catch (e) {
        formattedTime = '';
      }
    }

    return ParkingRecord(
      vehicle: json['vehicle_type_name'] ?? '-',
      time: formattedTime,
      status: 'Keluar',
      plate: json['plate_number'] ?? '',
      dateTime: dateTime,
    );
  }
}

class ParkingHistorySection {
  final DateTime date;
  final List<ParkingRecord> records;

  ParkingHistorySection({required this.date, required this.records});

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sectionDay = DateTime(date.year, date.month, date.day);

    if (sectionDay == today) return 'Hari Ini';
    if (sectionDay == yesterday) return 'Kemarin';
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }
}

class Histori extends StatefulWidget {
  const Histori({Key? key}) : super(key: key);

  @override
  _HistoriState createState() => _HistoriState();
}

class _HistoriState extends State<Histori> {
  bool isLoading = true;
  List<ParkingHistorySection> historyList = [];
  String? errorMessage;
  DateTime? _selectedDate;

  static const _primary = Color(0xFF1D1540);
  static const _accent  = Color(0xFF4F3CC9);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final saved = await LocalDbService.getLogin();
      final token = saved?['token'];
      if (token == null) {
        setState(() { errorMessage = 'Token tidak ditemukan'; isLoading = false; });
        return;
      }
      await _fetchHistory(token);
    } catch (e) {
      setState(() { errorMessage = 'Gagal: $e'; isLoading = false; });
    }
  }

  Future<void> _fetchHistory(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/parking-records/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        final List<ParkingRecord> all = [];

        for (var item in data) {
          if (item['entry_time'] != null && item['entry_time'].toString().isNotEmpty) {
            try { all.add(ParkingRecord.fromRawJsonEntry(item)); } catch (_) {}
          }
          if (item['exit_time'] != null && item['exit_time'].toString().isNotEmpty) {
            try { all.add(ParkingRecord.fromRawJsonExit(item)); } catch (_) {}
          }
        }

        final Map<DateTime, List<ParkingRecord>> grouped = {};
        for (var r in all) {
          final d = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
          grouped.putIfAbsent(d, () => []).add(r);
        }

        grouped.forEach((_, records) => records.sort((a, b) => b.dateTime.compareTo(a.dateTime)));

        final sections = grouped.entries
            .map((e) => ParkingHistorySection(date: e.key, records: e.value))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        setState(() { historyList = sections; isLoading = false; });
      } else {
        setState(() { errorMessage = 'Gagal memuat data (${res.statusCode})'; isLoading = false; });
      }
    } catch (e) {
      setState(() { errorMessage = 'Koneksi gagal: $e'; isLoading = false; });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      locale: const Locale('id', 'ID'),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedDate == null
        ? historyList
        : historyList.where((s) {
            final d = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
            return s.date == d;
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: _primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Riwayat Parkir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, _accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30, top: -30,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 40, top: 20,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Filter Bar ──
          SliverToBoxAdapter(
            child: Container(
              color: _primary,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedDate != null
                                  ? _accent.withOpacity(0.4)
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 16,
                                  color: _selectedDate != null ? _accent : Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate == null
                                    ? 'Filter tanggal'
                                    : DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate!),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _selectedDate != null ? _primary : Colors.grey.shade500,
                                  fontWeight: _selectedDate != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate = null),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: Colors.red.shade400),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loadData,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            size: 16, color: _accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──
          if (isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: _accent),
              ),
            )
          else if (errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.wifi_off_rounded,
                            size: 36, color: Colors.red.shade300),
                      ),
                      const SizedBox(height: 16),
                      Text(errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.history_rounded,
                          size: 40, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedDate != null
                          ? 'Tidak ada riwayat\npada tanggal ini'
                          : 'Belum ada riwayat parkir',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final section = filtered[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 4, height: 16,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                section.formattedDate,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _primary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '${section.records.length} aktivitas',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...section.records.map(_buildCard).toList(),
                      ],
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(ParkingRecord record) {
    final isMasuk = record.status == 'Masuk';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Color bar kiri ──
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: isMasuk ? const Color(0xFF12B76A) : const Color(0xFFEF4444),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),

          // ── Icon ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isMasuk
                  ? const Color(0xFF12B76A).withOpacity(0.1)
                  : const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isMasuk ? Icons.login_rounded : Icons.logout_rounded,
              size: 20,
              color: isMasuk
                  ? const Color(0xFF12B76A)
                  : const Color(0xFFEF4444),
            ),
          ),

          // ── Info ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        record.plate,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _primary,
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMasuk
                              ? const Color(0xFF12B76A).withOpacity(0.1)
                              : const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          record.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isMasuk
                                ? const Color(0xFF12B76A)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.vehicle.isEmpty ? 'Tidak terdaftar' : record.vehicle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Waktu ──
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              record.time,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _primary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
