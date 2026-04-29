import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'package:google_sign_in/google_sign_in.dart';

bool _isObscure = true;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ── สีธีมหลัก ──
  static const Color _pink = Color(0xFFE91E8C);
  static const Color _lightPink = Color(0xFFFCE4EC);
  static const Color _softPink = Color(0xFFF8BBD0);
  static const Color _deepPink = Color(0xFFC2185B);

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      final isAdmin = user?.email == 'admintoilet0012@gmail.com';

      if (user?.emailVerified == false && !isAdmin) {
        
        // ----------------------------------------------------
        // แทรกโค้ดตรงนี้: สั่งส่งลิงก์ใหม่ก่อนที่จะเตะออก
        try {
          await user?.sendEmailVerification();
        } catch (e) {
          print("ไม่สามารถส่งอีเมลซ้ำได้: $e");
        }
        // ----------------------------------------------------

        // เตะออกจากระบบ
        await FirebaseAuth.instance.signOut();

        // Best Practice: เช็คว่า Widget ยังอยู่บนหน้าจอก่อนจะใช้ BuildContext
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text(
              "🔒 ยืนยันอีเมล",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.pink, // หรือใช้ _deepPink ตามที่คุณกำหนดไว้
                fontSize: 18,
              ),
            ),
            content: Text(
              // ปรับข้อความเพื่อบอกว่าเราเพิ่งส่งลิงก์ใหม่ไปให้
              "กรุณายืนยันอีเมลของคุณก่อนเข้าใช้งานค่ะ\nตรวจสอบลิงก์ยืนยันในกล่องจดหมายขยะ (Spam)\n\nหากไม่ยืนยันใน 3 วัน ลิงก์เก่าอาจหมดอายุ เราได้ส่งลิงก์ยืนยันไปใหม่อีกรอบแล้ว!",
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("ตกลงเข้าใจแล้ว",
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        return; // สั่งหยุดทำงาน ไม่ให้มันไหลลงไปบรรทัดข้างล่าง
      }
      
      // 🚨 --- เพิ่มโค้ดส่วนนี้เพื่อพาเข้าหน้า Home --- 🚨
      if (!mounted) return;

      // ถ้าผ่านด่านด้านบนมาได้ (คือเป็น Admin หรือยืนยันอีเมลแล้ว) ให้พาวาร์ปเข้าหน้า Home!
      Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) => const HomePage()),);
      // -------------------------------------------------

    } on FirebaseAuthException catch (e) {
      String message = "เกิดข้อผิดพลาด กรุณา login";
      if (e.code == 'user-not-found') message = "ไม่พบอีเมลนี้ในระบบ";
      else if (e.code == 'invalid-credential') message = "อีเมลหรือรหัสผ่านไม่ถูกต้อง";
      
      if (!mounted) return;
      // โชว์ SnackBar แจ้งเตือน Error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ));
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError ? _deepPink : _pink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  void loginAsGuest() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HomePage()));
  }

  Future<void> signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut();
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // ล็อกอินเข้า Firebase สำเร็จ
      await FirebaseAuth.instance.signInWithCredential(credential);

      // --- 🚨 สิ่งที่ต้องเพิ่มเข้าไปคือส่วนนี้ครับ 🚨 ---
      // เช็คว่าหน้าจอยังเปิดอยู่ไหม (Best Practice)
      if (!mounted) return; 

      // สั่งให้เปลี่ยนหน้าไปที่ HomePage และลบหน้า Login ทิ้งไปเลยไม่ให้กด Back กลับมาได้
      Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) => const HomePage()),);
      // ----------------------------------------------

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Google Error: ${e.toString()}"),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
      print("Google Error: $e");
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // ── โลโก้ ──
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_pink, _deepPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: _pink.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wc, size: 60, color: Colors.white),
                ),

                const SizedBox(height: 28),

                // ── ชื่อแอป ──
                const Text(
                  "Hong Nam",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFC2185B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "ค้นหาห้องน้ำใกล้บ้านคุณได้เลย",
                  style: TextStyle(fontSize: 14, color: Colors.pink[300]),
                ),

                const SizedBox(height: 40),

                // ── การ์ด ──
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _softPink.withOpacity(0.6),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "เข้าสู่ระบบ",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC2185B),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ช่อง Email
                      _buildTextField(
                        controller: _emailController,
                        label: "อีเมล",
                        icon: Icons.email_rounded,
                      ),
                      const SizedBox(height: 16),

                      // ช่อง Password
                      _buildTextField(
                        controller: _passwordController,
                        label: "รหัสผ่าน",
                        icon: Icons.lock_rounded,
                        isPassword: true,
                      ),
                      const SizedBox(height: 28),

                      // ปุ่ม Login
                      _buildPrimaryButton("เข้าสู่ระบบ", login),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── ปุ่ม Google ──
                _buildGoogleButton(),

                const SizedBox(height: 20),

                // ── ลิงก์สมัคร ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("ยังไม่มีบัญชีใช่ไหม?",
                        style: TextStyle(color: Colors.pink[400])),
                    TextButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RegisterPage())),
                      child: const Text(
                        "สมัครสมาชิก",
                        style: TextStyle(
                          color: _deepPink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Guest ──
                TextButton(
                  onPressed: loginAsGuest,
                  child: Text(
                    "เข้าใช้งานแบบ Guest (ผู้เยี่ยมชม)",
                    style: TextStyle(
                      color: Colors.pink[300],
                      decoration: TextDecoration.underline,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
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
                  _isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: signInWithGoogle,
        icon: Image.asset(
          'assets/icons/google-icon.png',
          height: 22,
          width: 22,
          fit: BoxFit.contain,
        ),
        label: const Text(
          "เข้าสู่ระบบด้วย Google",
          style: TextStyle(
            color: Color(0xFF4A4A4A),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _softPink, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white.withOpacity(0.85),
        ),
      ),
    );
  }
}