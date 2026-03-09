import 'package:firebase_auth/firebase_auth.dart'; // 1. นำเข้าแพ็กเกจ Firebase Auth
import 'package:flutter/material.dart';

// สร้างตัวแปรจำสถานะการซ่อนรหัสผ่าน (เริ่มต้นให้ซ่อนไว้ก่อน)
bool _isObscure = true;

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
  // ฟังก์ชันสมัครสมาชิก (ทำงานเมื่อกดปุ่ม)
  Future<void> register() async {
    // ด่านตรวจที่ 1: เช็คว่าช่องอีเมลหรือรหัสผ่านถูกปล่อยว่างไว้หรือไม่
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกอีเมลและรหัสผ่านให้ครบถ้วน")),
      );
      return; // หยุดการทำงานของฟังก์ชันทันที
    }

    // ด่านตรวจที่ 2: เช็คความยาวรหัสผ่านว่าน้อยกว่า 6 ตัวอักษรหรือไม่
    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร"),
        ),
      );
      return;
    }

    // ด่านตรวจที่ 3: เช็คว่ากรอกรหัสผ่านทั้งสองช่องตรงกันไหม (โค้ดเดิมของคุณ)
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("รหัสผ่านไม่ตรงกัน")));
      return;
    }

    try {
      // 1. ส่งข้อมูลไปสร้าง user ใน Firebase
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. สั่งให้ส่งอีเมลยืนยันตัวตนไปที่อีเมลที่เพิ่งสมัคร
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();

      // 3. เตะผู้ใช้ออกจากระบบ (Sign Out) เพื่อไม่ให้แอบเข้าใช้งานก่อนกดยืนยันอีเมล
      await FirebaseAuth.instance.signOut();

      // 4. แจ้งเตือนผู้ใช้ว่าสมัครสำเร็จแล้ว และปิดหน้านี้ทิ้ง
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "สมัครสำเร็จ! กรุณากดยืนยันตัวตนในอีเมล (หากไม่พบ โปรดตรวจสอบในกล่องจดหมายขยะหรือ Spam)",
          ),
          duration: Duration(seconds: 5), // ให้มันโชว์ค้างไว้นานขึ้นนิดนึง
        ),
      );
      Navigator.pop(context); // เด้งกลับไปหน้า Login
    } on FirebaseAuthException catch (e) {
      // ดักจับ Error เฉพาะที่มาจาก Firebase (เช่น อีเมลนี้มีคนสมัครไปแล้ว)
      String message = "เกิดข้อผิดพลาดในการสมัคร";
      if (e.code == 'email-already-in-use') {
        message = "อีเมลนี้มีผู้ใช้งานในระบบแล้ว";
      } else if (e.code == 'invalid-email') {
        message = "รูปแบบอีเมลไม่ถูกต้อง";
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
                      _isObscure ? Icons.visibility_off : Icons.visibility,
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
              SizedBox(height: 15),

              TextField(
                controller: _confirmPasswordController, // ผูกตัวควบคุม
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: "ยืนยันรหัสผ่าน",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                  // 2. เพิ่มส่วน suffixIcon (ไอคอนต่อท้าย) ตรงนี้
                  suffixIcon: IconButton(
                    icon: Icon(
                      // ตรรกะ: ถ้า _isObscure เป็น true ให้โชว์ลูกตาปิด (visibility_off)
                      // แต่ถ้าเป็น false ให้โชว์ลูกตาเปิด (visibility)
                      _isObscure ? Icons.visibility_off : Icons.visibility,
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

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      register, // เรียกใช้ฟังก์ชัน register ที่เขียนไว้ข้างบน
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
