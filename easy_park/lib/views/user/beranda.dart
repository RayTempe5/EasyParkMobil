import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:easy_park/constants/api_config.dart';
import 'package:easy_park/services/local_db_service.dart';
import 'package:easy_park/views/user/PanduanPage.dart';

class Beranda extends StatefulWidget {
  const Beranda({Key? key}) : super(key: key);
  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> {
  bool isLoading = true;
  String statusText = '-';
  String statusTime = '-';

  // chart data: { 'Mon': {'masuk': 2, 'keluar': 1}, ... }
  Map<String, Map<String, int>> chartData = {};
  int _touchedIndex = -1;

  static const _primary = Color(0xFF1A1A4B);
  static const _accent  = Color(0xFF4A3AFF);
  static const _green   = Color(0xFF12B76A);
  static const _red     = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final saved = await LocalDbService.getLogin();
      final token = saved?['token'];
      if (token == null) return;
      await Future.wait([
        _fetchStatus(token),
        _fetchHistory(token),
      ]);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchStatus(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/parking-records/last-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final status = (data['status'] ?? '').toString().toLowerCase();
        final entryTime = data['entry_time'];
        final exitTime  = data['exit_time'];

        String timeStr = '-';
        if (status == 'parked' && entryTime != null) {
          timeStr = _fmt(entryTime);
        } else if (exitTime != null) {
          timeStr = _fmt(exitTime);
        }

        setState(() {
          statusText = status == 'parked' ? 'Terparkir'
              : status == 'completed' ? 'Sudah Keluar' : '-';
          statusTime = timeStr;
        });
      }
    } catch (e) {
      debugPrint('fetchStatus error: $e');
    }
  }

  Future<void> _fetchHistory(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/parking-records/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        final Map<String, Map<String, int>> grouped = {};

        // Ambil 7 hari terakhir
        final now = DateTime.now();
        for (int i = 6; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          final key = _dayKey(d);
          grouped[key] = {'masuk': 0, 'keluar': 0};
        }

        for (var item in data) {
          if (item['entry_time'] != null) {
            try {
              final dt = DateTime.parse(item['entry_time']).toLocal();
              final key = _dayKey(dt);
              if (grouped.containsKey(key)) {
                grouped[key]!['masuk'] = (grouped[key]!['masuk'] ?? 0) + 1;
              }
            } catch (_) {}
          }
          if (item['exit_time'] != null) {
            try {
              final dt = DateTime.parse(item['exit_time']).toLocal();
              final key = _dayKey(dt);
              if (grouped.containsKey(key)) {
                grouped[key]!['keluar'] = (grouped[key]!['keluar'] ?? 0) + 1;
              }
            } catch (_) {}
          }
        }

        setState(() => chartData = grouped);
      }
    } catch (e) {
      debugPrint('fetchHistory error: $e');
    }
  }

  String _dayKey(DateTime dt) => DateFormat('E', 'id_ID').format(dt);

  String _fmt(String? t) {
    if (t == null || t.isEmpty) return '-';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(t).toLocal());
    } catch (_) { return '-'; }
  }

  @override
  Widget build(BuildContext context) {
    final userName = 'Pengguna';
    final isParkir = statusText == 'Terparkir';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : RefreshIndicator(
                onRefresh: _load,
                color: _accent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Halo,',
                                  style: TextStyle(fontSize: 14,
                                      color: Colors.grey.shade500)),
                              Text(userName,
                                  style: const TextStyle(fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: _primary)),
                            ]),
                          SvgPicture.asset('assets/park.svg',
                              width: 110, height: 75),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Status Card ──
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, Color(0xFF3A2EA8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: _primary.withOpacity(0.3),
                                blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Stack(children: [
                          // decoration circles
                          Positioned(right: -20, top: -20,
                              child: _circle(120, Colors.white.withOpacity(0.06))),
                          Positioned(right: 100, bottom: -10,
                              child: _circle(70, Colors.white.withOpacity(0.06))),

                          Padding(
                            padding: const EdgeInsets.all(22),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status Parkir',
                                        style: TextStyle(color: Colors.white.withOpacity(0.7),
                                            fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Text(statusText,
                                        style: const TextStyle(color: Colors.white,
                                            fontSize: 28, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Row(children: [
                                        Icon(Icons.access_time_rounded,
                                            size: 12,
                                            color: Colors.white.withOpacity(0.8)),
                                        const SizedBox(width: 4),
                                        Text(statusTime,
                                            style: TextStyle(color: Colors.white.withOpacity(0.9),
                                                fontSize: 12, fontWeight: FontWeight.w600)),
                                      ]),
                                    ),
                                  ]),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isParkir
                                        ? _green.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    isParkir
                                        ? Icons.local_parking_rounded
                                        : Icons.directions_car_rounded,
                                    color: isParkir ? _green : Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // ── Fitur ──
                      const Text('Fitur',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700, color: _primary)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _featureBtn(
                          'Kontak', 'assets/call.svg',
                          const Color(0xFFEDE9FF),
                          onTap: () => showDialog(context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Kontak'),
                              content: const Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Telepon: 0812-3456-7890'),
                                  SizedBox(height: 8),
                                  Text('Email: support@easypark.com'),
                                ],
                              ),
                              actions: [TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Tutup'))],
                            ),
                          ),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _featureBtn(
                          'Panduan', 'assets/guide.svg',
                          const Color(0xFFFFF3E0),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PanduanPage())),
                        )),
                      ]),
                      const SizedBox(height: 24),

                      // ── Bar Chart ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Aktivitas 7 Hari',
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w700, color: _primary)),
                          Row(children: [
                            _legend(_green, 'Masuk'),
                            const SizedBox(width: 12),
                            _legend(_red, 'Keluar'),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildChart(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildChart() {
    if (chartData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('Belum ada data',
            style: TextStyle(color: Colors.grey))),
      );
    }

    final keys   = chartData.keys.toList();
    final maxVal = chartData.values
        .expand((m) => m.values)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();
    final yMax = maxVal < 3 ? 4.0 : (maxVal + 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: yMax,
            minY: 0,
            groupsSpace: 14,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _primary,
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, gi, rod, ri) {
                  final label = ri == 0 ? 'Masuk' : 'Keluar';
                  return BarTooltipItem(
                    '$label\n${rod.toY.toInt()}x',
                    const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600),
                  );
                },
              ),
              touchCallback: (event, response) {
                setState(() {
                  _touchedIndex = response?.spot?.touchedBarGroupIndex ?? -1;
                });
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: yMax <= 4 ? 1 : (yMax / 4).ceilToDouble(),
                  getTitlesWidget: (val, _) => Text(
                    val.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (val, _) {
                    final i = val.toInt();
                    if (i < 0 || i >= keys.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(keys[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == _touchedIndex
                                ? FontWeight.w700 : FontWeight.w500,
                            color: i == _touchedIndex
                                ? _accent : Colors.grey.shade500,
                          )),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yMax <= 4 ? 1 : (yMax / 4).ceilToDouble(),
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.grey.shade100, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(keys.length, (i) {
              final key    = keys[i];
              final masuk  = (chartData[key]?['masuk']  ?? 0).toDouble();
              final keluar = (chartData[key]?['keluar'] ?? 0).toDouble();
              final touched = i == _touchedIndex;

              return BarChartGroupData(
                x: i,
                groupVertically: false,
                barRods: [
                  BarChartRodData(
                    toY: masuk,
                    color: touched ? _green : _green.withOpacity(0.75),
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true, toY: yMax,
                      color: Colors.grey.shade50,
                    ),
                  ),
                  BarChartRodData(
                    toY: keluar,
                    color: touched ? _red : _red.withOpacity(0.75),
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true, toY: yMax,
                      color: Colors.grey.shade50,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _featureBtn(String title, String icon, Color bg,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SvgPicture.asset(icon, width: 30, height: 30),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _primary)),
        ]),
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color,
            borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11,
        color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
  ]);

  Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}