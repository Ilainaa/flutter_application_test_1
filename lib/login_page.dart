import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'register_page.dart';
import 'home_page.dart'; // อย่าลืม import หน้า Home

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


    } on FirebaseAuthException catch (e) {
      // จัดการกรณีรหัสผิด หรือหา User ไม่เจอ
      String message = "เกิดข้อผิดพลาด";
      if (e.code == 'user-not-found') {
        message = "ไม่พบอีเมลนี้ในระบบ";
      } else if (e.code == 'wrong-password') {
        message = "รหัสผ่านไม่ถูกต้อง";
      } else if (e.code == 'invalid-credential') {
        message = "อีเมลหรือรหัสผ่านไม่ถูกต้อง"; // Firebase รุ่นใหม่จะรวม Error เป็นตัวนี้
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
        SnackBar(backgroundColor: Colors.red, content: Text("เข้าสู่ระบบ Guest ล้มเหลว")),
      );
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
              obscureText: true,
              decoration: InputDecoration(
                labelText: "รหัสผ่าน",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
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

            // โซนกดไปหน้าสมัครสมาชิก
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("ยังไม่มีบัญชีใช่ไหม?"),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterPage()),
                    );
                  },
                  child: Text("สมัครสมาชิกที่นี่", style: TextStyle(color: Colors.brown)),
                ),
              ],
            ),

            TextButton(
              onPressed: loginAsGuest, // เรียกฟังก์ชัน Guest
              child: Text(
                "เข้าใช้งานแบบ Guest (ผู้เยี่ยมชม)", 
                style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline),
              ),
            ),
            
          ],
        ),
      ),
    );
  }
}