import 'package:firebase_auth/firebase_auth.dart'; // 1. นำเข้าแพ็กเกจ Firebase Auth
import 'package:flutter/material.dart';

// เปลี่ยนเป็น StatefulWidget เพื่อให้จัดการข้อมูลได้
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 2. สร้างตัวควบคุม (Controller) เพื่อดึงข้อความจากช่องกรอก
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 3. ฟังก์ชันสมัครสมาชิก (ทำงานเมื่อกดปุ่ม)
  Future<void> register() async {
    // เช็คว่ากรอกรหัสตรงกันไหม
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("รหัสผ่านไม่ตรงกัน")),
      );
      return;
    }

    try {
      // --- คำสั่งสำคัญ: ส่งข้อมูลไปสร้าง user ใน Firebase ---
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(), // trim() เพื่อตัดช่องว่างหน้าหลังออก
        password: _passwordController.text.trim(),
      );

      // ถ้าผ่านบรรทัดบนมาได้ แปลว่าสมัครสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("สมัครสมาชิกสำเร็จ! ยินดีต้อนรับ Hero หน้าใหม่")),
      );
      
      // ปิดหน้านี้กลับไปหน้า Login
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      // ถ้ามี Error จาก Firebase (เช่น อีเมลซ้ำ, รหัสสั้นไป)
      String message = "เกิดข้อผิดพลาด";
      if (e.code == 'weak-password') {
        message = "รหัสผ่านง่ายเกินไป (ต้อง 6 ตัวขึ้นไป)";
      } else if (e.code == 'email-already-in-use') {
        message = "อีเมลนี้มีคนใช้แล้ว";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("สมัครสมาชิก Hero"),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.person_add, size: 80, color: Colors.brown),
              SizedBox(height: 20),
              
              TextField(
                controller: _emailController, // ผูกตัวควบคุม
                decoration: InputDecoration(
                  labelText: "อีเมล",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              SizedBox(height: 15),

              TextField(
                controller: _passwordController, // ผูกตัวควบคุม
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "รหัสผ่าน",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              SizedBox(height: 15),

              TextField(
                controller: _confirmPasswordController, // ผูกตัวควบคุม
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "ยืนยันรหัสผ่าน",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: register, // เรียกใช้ฟังก์ชัน register ที่เขียนไว้ข้างบน
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("ยืนยันการสมัคร", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}