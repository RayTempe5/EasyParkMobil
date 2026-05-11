import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_park/views/user/beranda.dart';
import 'package:easy_park/views/user/kendaraan.dart';
import 'package:easy_park/views/user/histori.dart';
import 'package:easy_park/views/user/profile.dart';

class BottomNavigationWidget extends StatefulWidget {
  final int initialTab;
  const BottomNavigationWidget({Key? key, this.initialTab = 0}) : super(key: key);
  @override
  _BottomNavigationWidgetState createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget> {
  late int _selectedIndex;

  static const _primary = Color(0xFF1A1A4B);
  static const _accent  = Color(0xFF4A3AFF);

  final List<Widget> _pages = [
    const Beranda(),
    const KendaraanScreen(),
    const Histori(),
    const Profile(),
  ];

  final _items = [
    {'icon': 'assets/beranda.svg',   'label': 'Beranda'},
    {'icon': 'assets/kendaraan.svg', 'label': 'Kendaraan'},
    {'icon': 'assets/histori.svg',   'label': 'Histori'},
    {'icon': 'assets/profile.svg',   'label': 'Profil'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: List.generate(_items.length, (i) => Expanded(
                child: _buildNavItem(i),
              )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    final item = _items[index];

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 36 : 28,
              height: isSelected ? 36 : 28,
              decoration: BoxDecoration(
                color: isSelected ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: SvgPicture.asset(
                  item['icon']!,
                  width: isSelected ? 18 : 22,
                  height: isSelected ? 18 : 22,
                  colorFilter: ColorFilter.mode(
                    isSelected ? Colors.white : Colors.grey.shade400,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? _accent : Colors.grey.shade400,
              ),
              child: Text(item['label']!, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}