import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_park/services/auth_service.dart';
import 'package:easy_park/views/auth/forgot_password_screen.dart';
import 'package:easy_park/widgets/Bottom_Navigation.dart';
import 'package:easy_park/widgets/Drawer_Navigation.dart';
import 'package:easy_park/services/local_db_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _obscure      = true;
  bool _submitting   = false;
  bool _emailErr     = false;
  bool _passErr      = false;
  String _emailErrTxt = '';
  String _passErrTxt  = '';

  static const _primary = Color(0xFF1A1A4B);
  static const _accent  = Color(0xFF4A3AFF);
  static const _orange  = Color(0xFFFF9228);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validEmail(String e) =>
      RegExp(r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(e);

  void _checkEmail(String v) => setState(() {
    if (v.isEmpty)        { _emailErr = true;  _emailErrTxt = 'Email tidak boleh kosong'; }
    else if (!_validEmail(v)) { _emailErr = true; _emailErrTxt = 'Format email tidak valid'; }
    else                  { _emailErr = false; _emailErrTxt = ''; }
  });

  void _checkPass(String v) => setState(() {
    if (v.isEmpty)      { _passErr = true; _passErrTxt = 'Password tidak boleh kosong'; }
    else if (v.length < 6)  { _passErr = true; _passErrTxt = 'Password minimal 6 karakter'; }
    else if (!v.contains(RegExp(r'[0-9]'))) { _passErr = true; _passErrTxt = 'Harus mengandung minimal 1 angka'; }
    else                { _passErr = false; _passErrTxt = ''; }
  });

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(fontSize: 14,
            fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  Future<void> _login() async {
    _checkEmail(_emailCtrl.text);
    _checkPass(_passwordCtrl.text);
    if (_emailErr || _passErr) { _snack('Perbaiki kesalahan pada form', isError: true); return; }

    setState(() => _submitting = true);
    try {
      final result = await AuthService.login(_emailCtrl.text, _passwordCtrl.text);
      if (result['success'] == true) {
        _snack(result['message'] ?? 'Login berhasil');
        final role       = result['role'];
        final redirectTo = result['redirect_to'];

        await LocalDbService.saveLogin(
          email: _emailCtrl.text,
          token: result['token'],
          role: role,
          userJson: jsonEncode(result['user']),
        );

        Widget? target;
        if (redirectTo == 'Bottom_Navigation') target = const BottomNavigationWidget();
        else if (redirectTo == 'petugasHome')  target = const DrawerNavigationwidget();
        else { _snack('Redirect tidak valid', isError: true); return; }

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => target!));
      } else {
        _snack(result['message'] ?? 'Login gagal', isError: true);
      }
    } catch (e) {
      _snack('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Header area ──
          Container(
            height: h * 0.36,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, Color(0xFF3A2EA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(children: [
              // decorative circles
              Positioned(right: -40, top: -40,
                  child: _circle(200, Colors.white.withOpacity(0.05))),
              Positioned(left: -20, bottom: 20,
                  child: _circle(130, Colors.white.withOpacity(0.05))),
              Positioned(right: 60, top: 60,
                  child: _circle(70, Colors.white.withOpacity(0.07))),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SvgPicture.asset('assets/easy.svg',
                            height: 28, width: 28),
                      ),
                      const Spacer(),

                      Text('Selamat Datang',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.65),
                            letterSpacing: 0.5,
                          )),
                      const SizedBox(height: 4),
                      Text('Masuk ke EasyPark',
                          style: GoogleFonts.dmSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 8),
                      Text('Parkirkan kendaraanmu lebih aman\nbersama kami',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.65),
                            height: 1.5,
                          )),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ]),
          ),

          // ── Form area ──
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            transform: Matrix4.translationValues(0, -24, 0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Email ──
                    _label('Email'),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _emailCtrl,
                      hint: 'contoh@email.com',
                      icon: Icons.email_outlined,
                      hasError: _emailErr,
                      errorText: _emailErrTxt,
                      onChanged: _checkEmail,
                      keyboard: TextInputType.emailAddress,
                      showCheck: !_emailErr && _emailCtrl.text.isNotEmpty,
                    ),
                    const SizedBox(height: 20),

                    // ── Password ──
                    _label('Password'),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _passwordCtrl,
                      hint: 'Minimal 6 karakter + angka',
                      icon: Icons.lock_outline_rounded,
                      hasError: _passErr,
                      errorText: _passErrTxt,
                      onChanged: _checkPass,
                      obscure: _obscure,
                      showCheck: !_passErr && _passwordCtrl.text.isNotEmpty,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Forgot password ──
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen())),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Lupa Password?',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: _accent,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Login button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: _accent.withOpacity(0.4),
                        ),
                        child: _submitting
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.login_rounded,
                                      size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('MASUK',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      )),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: _primary));

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool hasError,
    required String errorText,
    required ValueChanged<String> onChanged,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    bool showCheck = false,
    Widget? suffix,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: hasError ? Colors.red.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError
                ? Colors.red.shade300
                : showCheck
                    ? Colors.green.shade300
                    : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(icon, size: 18,
                color: hasError ? Colors.red.shade400
                    : showCheck ? Colors.green.shade500
                    : Colors.grey.shade500),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboard,
              obscureText: obscure,
              onChanged: onChanged,
              style: GoogleFonts.dmSans(fontSize: 14, color: _primary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(
                    color: Colors.grey.shade400, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
              ),
            ),
          ),
          if (showCheck && suffix == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.check_circle_rounded,
                  size: 18, color: Colors.green.shade500),
            ),
          if (hasError && suffix == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.error_rounded,
                  size: 18, color: Colors.red.shade400),
            ),
          if (suffix != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: suffix,
            ),
        ]),
      ),
      if (hasError)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Row(children: [
            Icon(Icons.info_outline_rounded,
                size: 12, color: Colors.red.shade400),
            const SizedBox(width: 4),
            Text(errorText,
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: Colors.red.shade500)),
          ]),
        ),
    ]);
  }

  Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}