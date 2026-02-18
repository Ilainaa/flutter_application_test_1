import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  // ตัวแปรเก็บหมุด
  final Set<Marker> _markers = {};

  // ตัวแปรเก็บประเภทแผนที่ (เริ่มต้นเป็นแบบปกติ)
  MapType _currentMapType = MapType.normal;

  // ตัวแปรสำหรับ Profile
  String _myDescription = ""; 
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // ตำแหน่งเริ่มต้น (อนุสาวรีย์ฯ - กันเหนียวเผื่อหา GPS ไม่เจอ)
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(13.764953, 100.538316),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _determinePosition(); // หาพิกัดทันทีที่เปิดหน้า
  }

  // ฟังก์ชันขอพิกัดปัจจุบัน
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('GPS ปิดอยู่');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('User ไม่ยอมให้ใช้ GPS');
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    print("เจอตัวแล้ว! อยู่ที่: ${position.latitude}, ${position.longitude}");

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 17,
      ),
    ));
  }

  // --- ตัวแปรสำหรับระบบค้นหา ---
  final TextEditingController _searchController = TextEditingController();

  // ฟังก์ชันค้นหาสถานที่
  Future<void> _searchPlace() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      // แปลงชื่อสถานที่ที่พิมพ์ เป็นพิกัด Lat/Lng
      List<Location> locations = await locationFromAddress(query);
      
      if (locations.isNotEmpty) {
        // ถ้าเจอ ให้สั่งกล้องบินไปที่พิกัดนั้น
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(locations.first.latitude, locations.first.longitude),
            zoom: 16, // ซูมเข้าไปใกล้ๆ
          ),
        ));
      }
    } catch (e) {
      // ถ้าหาไม่เจอให้โชว์แจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("หาสถานที่ไม่เจอ ลองพิมพ์ให้ชัดเจนขึ้นครับ")),
      );
    }
  }
  // -------------------------

  // ฟังก์ชันสลับโหมดแผนที่ (ปกติ <-> ดาวเทียมผสม)
  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.hybrid
          : MapType.normal;
    });
  }

  // ฟังก์ชันเปิดหน้าต่างแก้โปรไฟล์
  void _showProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? "";
    _descController.text = _myDescription;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.brown),
              SizedBox(width: 10),
              Text("ตั้งค่าโปรไฟล์"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "ชื่อของคุณ (Username)",
                  hintText: "เช่น Hero นักปวด",
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: "คำอธิบาย (Description)",
                  hintText: "ข้อความที่จะโชว์เมื่อปักหมุด",
                  prefixIcon: Icon(Icons.description),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("ยกเลิก"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  await user?.updateDisplayName(_nameController.text);
                  await user?.reload(); 
                }
                
                setState(() {
                  _myDescription = _descController.text;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("บันทึกข้อมูลเรียบร้อย!")),
                );
              },
              child: Text("บันทึก"),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันปักหมุด (Logic เดิม เก็บไว้เผื่อใช้)
  void _addMarker(LatLng tappedPoint) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(tappedPoint.toString()),
          position: tappedPoint,
          infoWindow: InfoWindow(
            title: 'จุดเสี่ยงทาย',
            snippet: 'พิกัด: ${tappedPoint.latitude.toStringAsFixed(4)}, ${tappedPoint.longitude.toStringAsFixed(4)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  // Helper Widget สร้างปุ่มเมนู
  Widget _buildMenuButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isBig = false,
  }) {
    return Container(
      width: isBig ? 80 : 60,
      height: isBig ? 80 : 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Icon(
            icon,
            size: isBig ? 40 : 30,
            color: Colors.brown,
          ),
        ),
      ),
    );
  }

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    // ดึง User ปัจจุบันมาโชว์ชื่อ
    final user = FirebaseAuth.instance.currentUser;
    // สร้างตัวแปรเช็คว่าเป็น Guest ไหม? (ถ้าใช่จะเป็น true)
    final isGuest = user?.isAnonymous ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hero Map", style: TextStyle(fontSize: 18)),
            Text(
              user?.displayName ?? "Anonymous Hero", // ถ้าไม่มีชื่อให้โชว์ Anonymous
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
             onPressed: () => logout(context),
             icon: Icon(Icons.logout),
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. แผนที่ Google Map
          GoogleMap(
            mapType: _currentMapType, // ใช้ตัวแปรที่เราสลับโหมดได้
            initialCameraPosition: _defaultLocation,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true, // ปุ่มกลับหาตัวเองเปิดอยู่ตรงนี้
            markers: _markers,
            onLongPress: (LatLng point) {
              _addMarker(point);
            },
          ),

            // 2. ปุ่มหาสถานที่
          Positioned(
            top: 20, // ห่างจากขอบบน 20
            left: 15, // ห่างจากขอบซ้าย 15
            right: 60, // เว้นขวาไว้ 60 เพื่อไม่ให้ทับปุ่มเป้าหมาย (My Location) ของ Google
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white, // พื้นหลังสีขาว
                borderRadius: BorderRadius.circular(25), // ขอบโค้งมนแบบแคปซูล
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search, // เปลี่ยนปุ่ม Enter ในคีย์บอร์ดเป็นปุ่มค้นหา
                onSubmitted: (value) {
                  _searchPlace(); // เมื่อกด Enter ให้เริ่มหา
                },
                decoration: InputDecoration(
                  hintText: "ค้นหาสถานที่...",
                  border: InputBorder.none, // ซ่อนเส้นขอบ
                  contentPadding: EdgeInsets.only(left: 20, top: 15), // จัดข้อความให้อยู่ตรงกลาง
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: Colors.brown), // ไอคอนแว่นขยาย
                    onPressed: () {
                      _searchPlace(); // เมื่อกดแว่นขยาย ให้เริ่มหา
                      FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ด
                    },
                  ),
                ),
              ),
            ),
          ),
          // ---------------------------------------------

          // 3. ปุ่มเมนู 3 ปุ่มด้านล่าง
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // ปุ่มซ้าย: สลับดาวเทียม (ให้ดูได้ทุกคน ไม่ต้องซ่อน)
                _buildMenuButton(
                  icon: Icons.layers, 
                  onPressed: () {
                    _toggleMapType();
                  },
                ),
                
                // ปุ่มกลาง: เพิ่มห้องน้ำ (รอทำฟังก์ชัน)
                if (!isGuest) // แปลว่า "ถ้าไม่ใช่ Guest ถึงจะแสดง"
                  _buildMenuButton(
                    icon: Icons.add_location_alt,
                    isBig: true,
                    onPressed: () {
                      print("กดปุ่มเพิ่มห้องน้ำ");
                    },
                  ),
                
                // ปุ่มขวา: โปรไฟล์
                if (!isGuest) // แปลว่า "ถ้าไม่ใช่ Guest ถึงจะแสดง"
                  _buildMenuButton(
                    icon: Icons.person,
                    onPressed: () {
                      _showProfileDialog();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}