import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // เพิ่มตัวนี้เข้ามา

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  // ตำแหน่งเริ่มต้น (ตั้งไว้ที่อนุสาวรีย์ฯ ก่อนเผื่อหา GPS ไม่เจอ)
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(13.764953, 100.538316),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    // พอเปิดหน้านี้ปุ๊บ ให้เช็ค GPS ทันที
    _determinePosition(); 
  }

  // ฟังก์ชันขอพิกัดปัจจุบัน
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. เช็คว่าเปิด GPS หรือยัง?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('GPS ปิดอยู่');
      return;
    }

    // 2. เช็คว่าขออนุญาตแอปหรือยัง?
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('User ไม่ยอมให้ใช้ GPS');
        return;
      }
    }

    // 3. ถ้าผ่านหมด -> ดึงพิกัดปัจจุบันมา!
    Position position = await Geolocator.getCurrentPosition();
    print("เจอตัวแล้ว! อยู่ที่: ${position.latitude}, ${position.longitude}");

    // 4. สั่งให้กล้อง Map บินไปหาจุดนั้น
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 17, // ซูมเข้าไปใกล้ๆ
      ),
    ));
  }

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hero Map"),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => logout(context),
            icon: Icon(Icons.logout),
          )
        ],
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _defaultLocation,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        myLocationEnabled: true, // เปิดจุดสีฟ้า (Blue Dot)
        myLocationButtonEnabled: true, // เปิดปุ่มกดกลับมาหาตัวเอง
      ),
    );
  }
}