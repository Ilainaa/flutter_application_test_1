import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'register_page.dart';
import 'home_page.dart'; // อย่าลืม import หน้า Home
import 'package:google_sign_in/google_sign_in.dart';

// สร้างตัวแปรจำสถานะการซ่อนรหัสผ่าน (เริ่มต้นให้ซ่อนไว้ก่อน)
bool _isObscure = true;

// เปลี่ยนเป็น StatefulWidget
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // สร้างตัวควบคุมรับค่า Text
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ฟังก์ชัน Login
  Future<void> login() async {
    try {
      // สั่ง Firebase ให้ตรวจสอบ Email/Password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // จุดที่ 1: เช็คว่า User คนนี้ได้ยืนยันอีเมลแล้วหรือยัง
      if (FirebaseAuth.instance.currentUser?.emailVerified == false) {
        // จุดที่ 2: ถ้ายังไม่ยืนยัน ให้เตะผู้ใช้ออกจากระบบ (Sign Out) ทันที
        await FirebaseAuth.instance.signOut();

        // Best Practice: เช็คว่า Widget ยังอยู่บนหน้าจอก่อนจะใช้ BuildContext
        if (!mounted) return;

        // โชว์ข้อความแจ้งเตือนให้ไปเช็คอีเมล
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("กรุณายืนยันอีเมลของคุณก่อนเข้าใช้งาน")),
        );

        // จุดที่ 3: สั่ง Halt (หยุด) การทำงานของฟังก์ชันนี้ทันที เพื่อไม่ให้แอพเปิดไปหน้า Home
        return;
      }

    } on FirebaseAuthException catch (e) {
      // จัดการกรณีรหัสผิด หรือหา User ไม่เจอ
      String message = "เกิดข้อผิดพลาด";
      if (e.code == 'user-not-found') {
        message = "ไม่พบอีเมลนี้ในระบบ";
      } else if (e.code == 'wrong-password') {
        message = "รหัสผ่านไม่ถูกต้อง";
      } else if (e.code == 'invalid-credential') {
        message =
            "อีเมลหรือรหัสผ่านไม่ถูกต้อง"; // Firebase รุ่นใหม่จะรวม Error เป็นตัวนี้
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(message)),
      );
    }
  }

  Future<void> loginAsGuest() async {
    try {
      // สั่ง Firebase ให้สร้างไอดีชั่วคราวให้
      await FirebaseAuth.instance.signInAnonymously();
      // พอล็อกอินเสร็จ StreamBuilder ใน main.dart จะพาไปหน้า Home เอง
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("เข้าสู่ระบบ Guest ล้มเหลว"),
        ),
      );
    }
  }

  // ฟังก์ชัน Login ด้วย Google
  Future<void> signInWithGoogle() async {
    try {
      // 1. สั่งให้เปิดหน้าต่างเลือกบัญชี Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // ถ้าผู้ใช้กดปิดหน้าต่างไปเอง (ไม่ยอมล็อกอิน) ให้หยุดการทำงานทันที
      if (googleUser == null) return;

      // 2. ขอข้อมูลยืนยันตัวตน (Authentication) จากบัญชีที่เลือก
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. สร้างบัตรผ่าน (Credential) ด้วยข้อมูลจาก Google
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. เอาบัตรผ่านไปยื่นล็อกอินเข้า Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      // ถ้ามี Error อะไรเกิดขึ้น ให้แสดงผลออกมาดู
      // ถ้ามี Error อะไรเกิดขึ้น ให้แสดงเป็น SnackBar ให้ผู้ใช้เห็น
      print("เกิดข้อผิดพลาดในการล็อกอินด้วย Google: $e");
      if (mounted) {
        // ตรวจสอบว่า Widget ยังอยู่บนหน้าจอก่อนแสดง SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("การล็อกอินด้วย Google ล้มเหลว: ${e.toString()}"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wc, size: 100, color: Colors.brown),
            SizedBox(height: 20),
            Text(
              "เข้าสู่ระบบ Hero",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),

            // ช่อง Email
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "อีเมล",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            SizedBox(height: 20),

            // ช่อง Password
            TextField(
              controller: _passwordController,
              // 1. เปลี่ยนจาก true ตายตัว ให้มาใช้ค่าจากตัวแปรแทน
              obscureText: _isObscure, 
              decoration: InputDecoration(
                labelText: "รหัสผ่าน",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                
                // 2. เพิ่มส่วน suffixIcon (ไอคอนต่อท้าย) ตรงนี้
                suffixIcon: IconButton(
                  icon: Icon(
                    // ตรรกะ: ถ้า _isObscure เป็น true ให้โชว์ลูกตาปิด (visibility_off) 
                    // แต่ถ้าเป็น false ให้โชว์ลูกตาเปิด (visibility)
                    _isObscure ? Icons.visibility_off : Icons.visibility 
                  ),
                  onPressed: () {
                    // 3. ใช้ setState เพื่อสั่งให้หน้าจอกะพริบวาดใหม่
                    setState(() {
                      // สลับค่าตัวแปร: เครื่องหมาย ! แปลว่า "ตรงข้าม"
                      _isObscure = !_isObscure; 
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 30),

            // ปุ่ม Login
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: login, // เรียกฟังก์ชัน login
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
                child: Text("เข้าสู่ระบบ", style: TextStyle(fontSize: 18)),
              ),
            ),

            SizedBox(height: 20),

            // ปุ่ม Login ด้วย Google
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: signInWithGoogle,
                // ใช้ Image.asset เพื่อแสดงโลโก้จากไฟล์
                icon: Image.asset(
                  'assets/icons/Logo-google-icon-PNG.png',
                  height: 24.0,
                  width: 24.0, // <-- เพิ่มการจำกัดความกว้างตรงนี้
                  fit: BoxFit.contain, // <-- (แถม) ตัวนี้จะช่วยบังคับให้รูปย่อส่วนลงมาอยู่ในกรอบ 24x24 แบบพอดีเป๊ะ ไม่โดนตัดขอบครับ
                ),
                label: const Text(
                  "เข้าสู่ระบบด้วย Google",
                  style: TextStyle(color: Colors.black87, fontSize: 18),
                ),
              ),
            ),

            SizedBox(height: 20),

            // โซนกดไปหน้าสมัครสมาชิก
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("ยังไม่มีบัญชีใช่ไหม?"),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: Text(
                    "สมัครสมาชิกที่นี่",
                    style: TextStyle(color: Colors.brown),
                  ),
                ),
              ],
            ),

            TextButton(
              onPressed: loginAsGuest, // เรียกฟังก์ชัน Guest
              child: Text(
                "เข้าใช้งานแบบ Guest (ผู้เยี่ยมชม)",
                style: TextStyle(
                  color: Colors.grey,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
