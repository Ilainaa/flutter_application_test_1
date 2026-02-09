import 'package:firebase_auth/firebase_auth.dart'; // เพิ่มบรรทัดนี้
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'home_page.dart'; // เพิ่มบรรทัดนี้

// ต้องเปลี่ยนเป็น async เพื่อให้รอ Firebase เชื่อมต่อเสร็จก่อนค่อยเปิดแอป
void main() async {
  // 1. จำเป็นต้องเรียกตัวนี้เพื่อให้ Flutter พร้อมทำงานก่อนเริ่มระบบอื่น
  WidgetsFlutterBinding.ensureInitialized();

  // 2. สั่งให้เชื่อมต่อกับ Firebase (ใช้ไฟล์ google-services.json ที่เราโหลดมา)
  await Firebase.initializeApp();

  // 3. พอเชื่อมเสร็จ ค่อยสั่งรันแอป
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ปิดป้าย Debug มุมขวาบน
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown), // ธีมสีน้ำตาล (สไตล์ Khee/ห้องน้ำ)
        useMaterial3: true,
      ),
      // --- แก้จุดนี้ครับ ---
      // ใช้ StreamBuilder คอยฟังสถานะจาก Firebase ตลอดเวลา
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // ถ้ามีข้อมูล User (แปลว่าล็อกอินอยู่) -> ส่งไปหน้า Home ทันที
          if (snapshot.hasData) {
            return const HomePage();
          }
          // ถ้าไม่มีข้อมูล (แปลว่ายังไม่ล็อกอิน หรือ Logout แล้ว) -> ส่งไปหน้า Login
          return const LoginPage();
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
