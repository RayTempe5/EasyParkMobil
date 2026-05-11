import 'package:flutter/material.dart';

class PanduanPage extends StatefulWidget {
  const PanduanPage({Key? key}) : super(key: key);
  @override
  State<PanduanPage> createState() => _PanduanPageState();
}

class _PanduanPageState extends State<PanduanPage> {
  int? _expanded;

  static const _primary = Color(0xFF1A1A4B);
  static const _accent  = Color(0xFF4A3AFF);

  final _sections = [
    {
      'title': 'Beranda',
      'icon': Icons.home_rounded,
      'color': Color(0xFF4A3AFF),
      'bg': Color(0xFFEDE9FF),
      'items': [
        'Menampilkan status terakhir kendaraan (terparkir / sudah keluar)',
        'Grafik aktivitas masuk & keluar 7 hari terakhir',
        'Kontak untuk informasi jika ada kendala',
      ],
    },
    {
      'title': 'Kendaraan',
      'icon': Icons.directions_car_rounded,
      'color': Color(0xFF0EA5E9),
      'bg': Color(0xFFE0F2FE),
      'items': [
        'Menambahkan kendaraan baru ke akun',
        'Melihat daftar kendaraan yang terdaftar',
        'Mengedit atau menghapus data kendaraan',
        'Memilih kendaraan aktif yang sedang digunakan',
      ],
    },
    {
      'title': 'Histori',
      'icon': Icons.history_rounded,
      'color': Color(0xFF10B981),
      'bg': Color(0xFFD1FAE5),
      'items': [
        'Menampilkan riwayat parkir lengkap',
        'Filter berdasarkan tanggal tertentu',
        'Melihat waktu masuk dan keluar kendaraan',
      ],
    },
    {
      'title': 'Profil',
      'icon': Icons.person_rounded,
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFEF3C7),
      'items': [
        'Mengedit data profil pengguna',
        'Upload dan ubah foto profil',
        'Mendaftarkan wajah untuk verifikasi kiosk',
        'Logout dari akun',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: _primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
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
                      child: _circle(70, Colors.white.withOpacity(0.06))),
                  Positioned(left: 20, bottom: 32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Panduan',
                            style: TextStyle(fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Cara menggunakan EasyPark',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Intro banner ──
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _accent.withOpacity(0.08),
                        _accent.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _accent.withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lightbulb_outline_rounded,
                          color: _accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tips',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700, color: _primary)),
                        const SizedBox(height: 2),
                        Text('Ketuk setiap menu untuk melihat panduan lengkapnya.',
                            style: TextStyle(fontSize: 12,
                                color: Colors.grey.shade600, height: 1.4)),
                      ],
                    )),
                  ]),
                ),
              ),
            ),
          ),

          // ── Sections ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildSection(i),
                childCount: _sections.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(int i) {
    final s       = _sections[i];
    final isOpen  = _expanded == i;
    final color   = s['color'] as Color;
    final bg      = s['bg'] as Color;
    final icon    = s['icon'] as IconData;
    final title   = s['title'] as String;
    final items   = s['items'] as List<String>;

    return GestureDetector(
      onTap: () => setState(() => _expanded = isOpen ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOpen ? color.withOpacity(0.3) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isOpen
                  ? color.withOpacity(0.12)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700, color: _primary)),
                  Text('${items.length} panduan',
                      style: TextStyle(fontSize: 11,
                          color: Colors.grey.shade500)),
                ],
              )),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isOpen ? color.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isOpen ? color : Colors.grey.shade500),
                ),
              ),
            ]),
          ),

          // ── Items ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(children: [
              Divider(height: 1, color: Colors.grey.shade100),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: List.generate(items.length, (j) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22, height: 22,
                          margin: const EdgeInsets.only(right: 10, top: 1),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('${j + 1}',
                                style: TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                        ),
                        Expanded(child: Text(items[j],
                            style: TextStyle(fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.5))),
                      ],
                    ),
                  )),
                ),
              ),
            ]),
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ]),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}