import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E8C),
          primary: const Color(0xFFE91E8C),
          secondary: const Color(0xFFF48FB1),
          surface: const Color(0xFFFFF0F5),
        ),
        fontFamily: 'Kanit', // ถ้ามีฟอนต์ Kanit ในโปรเจกต์
        scaffoldBackgroundColor: const Color(0xFFFFF0F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE91E8C),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E8C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // ระหว่างรอโหลด ให้โชว์หน้าว่างๆ ไปก่อน
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // ถ้ามีข้อมูลผู้ใช้ล็อกอินเข้ามา
          if (snapshot.hasData) {
            final user = snapshot.data!;
            final isAdmin = user.email == 'admintoilet0012@gmail.com';

            // 🚨 ด่านตรวจความปลอดภัย: ต้องยืนยันอีเมลแล้ว หรือเป็น Admin เท่านั้นถึงจะเข้าได้
            if (user.emailVerified || isAdmin) {
              return const HomePage();
            } else {
              // ถ้าล็อกอินสำเร็จ แต่ "ยังไม่ยืนยันอีเมล" ให้บล็อกไว้หน้า Login เหมือนเดิม (แก้บั๊กจอกะพริบ)
              return const LoginPage();
            }
          }

          // ถ้าไม่มีข้อมูล (ยังไม่ล็อกอิน) หรือกด Logout ออกมา
          return const LoginPage();
        },
      ),
    );
  }
}