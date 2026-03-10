import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

bool _isObscure = true;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── สีธีมหลัก ──
  static const Color _pink = Color(0xFFE91E8C);
  static const Color _lightPink = Color(0xFFFCE4EC);
  static const Color _softPink = Color(0xFFF8BBD0);
  static const Color _deepPink = Color(0xFFC2185B);

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError ? _deepPink : _pink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  Future<void> register() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnackBar("กรุณากรอกอีเมลและรหัสผ่านให้ครบถ้วน", isError: true);
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      _showSnackBar("รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร", isError: true);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar("รหัสผ่านไม่ตรงกัน", isError: true);
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      _showSnackBar(
        "สมัครสำเร็จ! 🎉 กรุณายืนยันตัวตนในอีเมล (ตรวจสอบกล่อง Spam ด้วยนะคะ)",
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = "เกิดข้อผิดพลาดในการสมัคร";
      if (e.code == 'email-already-in-use') message = "อีเมลนี้มีผู้ใช้งานในระบบแล้ว";
      else if (e.code == 'invalid-email') message = "รูปแบบอีเมลไม่ถูกต้อง";
      _showSnackBar(message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F5), Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar แบบ custom ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _softPink.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: _deepPink),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      "สมัครสมาชิก",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _deepPink,
                      ),
                    ),
                  ],
                ),
              ),

              // ── เนื้อหา ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // ── ไอคอน ──
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF80AB), _pink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _pink.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            size: 46, color: Colors.white),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        "สร้างบัญชีใหม่",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _deepPink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "กรอกข้อมูลด้านล่างเพื่อเริ่มต้น",
                        style: TextStyle(fontSize: 14, color: Colors.pink[300]),
                      ),

                      const SizedBox(height: 32),

                      // ── ฟอร์ม ──
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _softPink.withOpacity(0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _emailController,
                              label: "อีเมล",
                              icon: Icons.email_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: "รหัสผ่าน",
                              icon: Icons.lock_rounded,
                              isPassword: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: "ยืนยันรหัสผ่าน",
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                            ),
                            const SizedBox(height: 28),
                            _buildPrimaryButton("ยืนยันการสมัคร", register),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── ข้อความกลับหน้า Login ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("มีบัญชีแล้ว?",
                              style: TextStyle(color: Colors.pink[400])),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "เข้าสู่ระบบ",
                              style: TextStyle(
                                color: _deepPink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _isObscure : false,
      style: const TextStyle(color: Color(0xFF4A0020)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.pink[300]),
        prefixIcon: Icon(icon, color: _pink),
        filled: true,
        fillColor: _lightPink.withOpacity(0.4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _softPink, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _pink, width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.pink[300],
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_pink, _deepPink],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _pink.withOpacity(0.45),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}