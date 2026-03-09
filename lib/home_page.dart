import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- 1. เพิ่ม Firestore เข้ามา
import 'dart:io'; // สำหรับจัดการไฟล์รูปภาพ
import 'package:image_picker/image_picker.dart'; // สำหรับเปิดแกลเลอรี่
import 'package:firebase_storage/firebase_storage.dart'; // สำหรับส่งรูปขึ้นฟ้า
import 'admin_page.dart'; // เพิ่มบรรทัดนี้เพื่อเรียกใช้หน้า Admin

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final Set<Marker> _markers = {};
  MapType _currentMapType = MapType.normal;
  final TextEditingController _searchController = TextEditingController();

  // ตัวแปรสำหรับ Profile
  String _myDescription = "";
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // --- 2. ตัวแปรใหม่สำหรับ "ระบบเล็งเป้าปักหมุด" ---
  bool _isPinningMode = false; // ตอนนี้อยู่ในโหมดเล็งเป้าหรือเปล่า?
  LatLng _currentMapCenter = const LatLng(13.764953, 100.538316); // เก็บพิกัดตรงกลางจอ
  // ------------------------------------------

  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(13.764953, 100.538316),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _determinePosition(); 
    _listenToApprovedToilets(); 
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 17,
      ),
    ));
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
  }

  Future<void> _searchPlace() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(locations.first.latitude, locations.first.longitude),
            zoom: 16,
          ),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("หาสถานที่ไม่เจอ ลองพิมพ์ให้ชัดเจนขึ้นครับ")),
      );
    }
  }

  // --- ฟังก์ชันดึงหมุดห้องน้ำมาโชว์บนแผนที่ ---
  void _listenToApprovedToilets() {
    FirebaseFirestore.instance
        .collection('toilets')
        .where('status', isEqualTo: 'approved') // ดึงเฉพาะอันที่อนุมัติแล้ว
        .snapshots()
        .listen((snapshot) {
          
      Set<Marker> newMarkers = {};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        LatLng position = LatLng(data['latitude'], data['longitude']);
        
        bool isFree = data['isFree'] ?? true; 
        bool isBroken = data['isBroken'] ?? false; // <-- 1. ดึงสถานะการชำรุดมาเช็ค
        
        // 2. กำหนดข้อความและสีของหมุด
        String titleText;
        double pinColor;

        if (isBroken) {
          titleText = '❌ ชำรุด / ปิดซ่อมแซม';
          pinColor = BitmapDescriptor.hueRed; // ถ้าพัง = สีแดง
        } else if (isFree) {
          titleText = '🆓 ห้องน้ำฟรี';
          pinColor = BitmapDescriptor.hueGreen; // ถ้าฟรีและใช้ได้ = สีเขียว
        } else {
          titleText = '💰 ห้องน้ำเสียเงิน';
          pinColor = BitmapDescriptor.hueOrange; // ถ้าเสียเงินและใช้ได้ = สีส้ม
        }

        newMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: position,
            onTap: () {
              // ต้องส่งรหัสหมุดไปให้รู้ด้วยว่า เรากำลังโหวตหมุดอันไหนอยู่
              _showToiletDetails(doc.id, data); 
            },
            icon: BitmapDescriptor.defaultMarkerWithHue(pinColor), // ใช้สีที่เราคำนวณไว้
          ),
        );
      }

      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    });
  }
  // ---------------------------------------------------------

  // --- ฟังก์ชันโชว์รายละเอียดเมื่อกดที่หมุด ---
  // --- ฟังก์ชันโชว์รายละเอียดพร้อมระบบคำนวณดาวเฉลี่ย ---
  void _showToiletDetails(String docId, Map<String, dynamic> data) {
    bool isFree = data['isFree'] ?? true;
    bool isBroken = data['isBroken'] ?? false;
    Map<String, dynamic> amenities = data['amenities'] ?? {};

    // จัดเตรียมข้อมูลเรื่องดาว
    final currentUser = FirebaseAuth.instance.currentUser;
    final String myUid = currentUser?.uid ?? 'anonymous';
    final bool isGuest = currentUser?.isAnonymous ?? false;

    // ดึงกล่องคะแนนมา (ถ้าไม่มีให้สร้างกล่องเปล่า)
    Map<String, dynamic> ratings = data['ratings'] != null 
        ? Map<String, dynamic>.from(data['ratings']) 
        : {};

    // (แถม) รองรับหมุดเก่าที่เคยเซฟดาวแบบ 'rating': 5 ทิ้งไว้ ไม่ให้แอปพัง
    if (ratings.isEmpty && data['rating'] != null) {
      ratings['legacy'] = data['rating']; 
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            
            // 1. คำนวณดาวเฉลี่ย และจำนวนคนโหวต
            double avgRating = 0.0;
            int totalVotes = ratings.length;
            if (totalVotes > 0) {
              double sum = 0;
              ratings.values.forEach((val) => sum += (val as num).toDouble());
              avgRating = sum / totalVotes; // หารหาค่าเฉลี่ย
            }

            // 2. ดูว่า User คนนี้เคยให้ดาวไว้กี่ดวง
            int myCurrentRating = ratings[myUid] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- รูปภาพ (ถ้ามี) ---
                  if (data['imageUrl'] != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        data['imageUrl'],
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],

                  // --- ส่วนหัว: สถานะ และ ดาวเฉลี่ย ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBroken ? '❌ ปิดซ่อมแซม' : (isFree ? '🆓 ห้องน้ำเข้าฟรี' : '💰 ห้องน้ำเสียเงิน'),
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          color: isBroken ? Colors.red : Colors.black
                        ),
                      ),
                      // โชว์ดาวเฉลี่ย
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 28),
                          const SizedBox(width: 5),
                          Text(
                            "${avgRating.toStringAsFixed(1)} ($totalVotes)", // เช่น 4.5 (2)
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // --- ข้อมูลพื้นฐาน ---
                  Row(
                    children: [
                      const Icon(Icons.wc, color: Colors.brown, size: 20),
                      const SizedBox(width: 8),
                      Text("สไตล์: ${data['toiletStyle'] ?? 'ไม่ระบุ'}", style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  if (!isFree && data['paymentMethod'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payment, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text("รับชำระ: ${data['paymentMethod']}", style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 15),

                  const Text("✨ สิ่งอำนวยความสะดวก:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      if (amenities['hasTissue'] == true) Chip(label: const Text("🧻 ทิชชู่"), backgroundColor: Colors.brown[50]),
                      if (amenities['hasBidet'] == true) Chip(label: const Text("🚿 สายชำระ"), backgroundColor: Colors.blue[50]),
                      if (amenities['hasSoap'] == true) Chip(label: const Text("🧼 สบู่"), backgroundColor: Colors.pink[50]),
                      if (amenities['hasTissue'] != true && amenities['hasBidet'] != true && amenities['hasSoap'] != true)
                        const Text("- ไม่มีข้อมูล -", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  const Text("📝 รายละเอียดเพิ่มเติม:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(
                    data['description'] != "" ? data['description'] : 'ไม่ได้ระบุรายละเอียดเพิ่มเติมไว้ครับ', 
                    style: const TextStyle(fontSize: 16, color: Colors.black87)
                  ),
                  const SizedBox(height: 20),
                  const Divider(),

                  // --- ส่วนใหม่: ระบบให้คะแนน (User Rating) ---
                  if (!isGuest) ...[
                    const Text("⭐ ให้คะแนนห้องน้ำนี้:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 5),
                    Row(
                      children: List.generate(5, (index) {
                        int starValue = index + 1;
                        return GestureDetector(
                          onTap: () async {
                            // 1. อัปเดตหน้าจอทันทีให้ User เห็นว่ากดติดแล้ว (ดาวสีทองขึ้น)
                            setSheetState(() {
                              ratings[myUid] = starValue;
                            });

                            // 2. ส่งข้อมูลขึ้นไปอัปเดตใน Firestore ทันที!
                            // ใช้คำสั่ง 'ratings.UID' เพื่ออัปเดตเฉพาะคะแนนของคนๆ นี้ ไม่ทับของคนอื่น
                            await FirebaseFirestore.instance.collection('toilets').doc(docId).update({
                              'ratings.$myUid': starValue,
                            });
                          },
                          child: Icon(
                            starValue <= myCurrentRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 36,
                          ),
                        );
                      }),
                    ),
                  ] else ...[
                    // ถ้าเป็น Guest จะให้โหวตไม่ได้
                    const Text("🔒 เข้าสู่ระบบแบบสมาชิกเพื่อร่วมให้คะแนนห้องน้ำนี้", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],

                  const SizedBox(height: 10),
                  Text(
                    "📍 ปักหมุดโดย: ${data['authorName'] ?? 'Anonymous Hero'}", 
                    style: const TextStyle(color: Colors.grey, fontSize: 12)
                  ),

                  // --- ส่วนใหม่: ปุ่มรายงานปัญหา 🚩 ---
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.flag, color: Colors.red),
                      label: const Text("รายงานปัญหา / แจ้งหมุดไม่ถูกต้อง", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        // เช็คเงื่อนไขว่าเป็น Guest หรือล็อกอินแล้ว
                        if (isGuest) {
                          // --- เปลี่ยนจาก SnackBar เป็น Dialog เด้งทับกลางจอ ---
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.lock, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text("แจ้งเตือน", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              content: const Text("ฟังก์ชันนี้สงวนไว้สำหรับสมาชิกครับ\nกรุณาเข้าสู่ระบบเพื่อร่วมรายงานปัญหา"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx), // กดตกลงเพื่อปิดหน้าต่างแจ้งเตือน
                                  child: const Text("ตกลง", style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
                                ),
                              ],
                            )
                          );
                          // ---------------------------------------------
                        } else {
                          // ถ้าล็อกอินแล้ว เรียกใช้หน้าต่างกรอกรายงาน
                          _showReportDialog(docId);
                        }
                      },
                    ),
                  ),
                  // ---------------------------------
                ],
              ),
            );
          }
        );
      }
    );
  }

  // --- ฟังก์ชันโชว์หน้าต่างกรอกรายงานปัญหา (สำหรับ User ที่ล็อกอินแล้ว) ---
  void _showReportDialog(String toiletId) {
    TextEditingController reportController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false, // ป้องกันการกดปิดตอนกำลังส่งข้อมูล
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.flag, color: Colors.red),
                  SizedBox(width: 8),
                  Text("รายงานปัญหา", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("พบปัญหาอะไรเกี่ยวกับห้องน้ำนี้ครับ?"),
                  SizedBox(height: 10),
                  TextField(
                    controller: reportController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "เช่น ชำรุด, สกปรกมาก, ปิดถาวร, หรือหมุดปลอม",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                if (!isSubmitting)
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: Text("ยกเลิก", style: TextStyle(color: Colors.grey))
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: isSubmitting ? null : () async {
                    if (reportController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("กรุณากรอกรายละเอียดปัญหาก่อนส่งครับ"))
                      );
                      return;
                    }

                    setDialogState(() => isSubmitting = true);
                    final user = FirebaseAuth.instance.currentUser;
                    
                    try {
                      // ส่งข้อมูลเข้า Collection ใหม่ที่ชื่อว่า 'reports'
                      await FirebaseFirestore.instance.collection('reports').add({
                        'toiletId': toiletId, // ไอดีหมุดที่มีปัญหา
                        'reason': reportController.text.trim(), // สาเหตุ
                        'reporterId': user?.uid, // ไอดีคนแจ้ง
                        'reporterName': user?.displayName ?? 'Anonymous Hero', // ชื่อคนแจ้ง
                        'timestamp': FieldValue.serverTimestamp(),
                        'status': 'pending', // รอแอดมินมาอ่าน
                      });

                      Navigator.pop(context); // ปิด popup
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("✅ ขอบคุณที่ช่วยรายงานครับ แอดมินจะรีบตรวจสอบ!"), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("❌ เกิดข้อผิดพลาด: $e"), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: isSubmitting 
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("ส่งรายงาน", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }
  // -------------------------------------------------------------

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
                decoration: InputDecoration(labelText: "ชื่อของคุณ (Username)", prefixIcon: Icon(Icons.person)),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _descController,
                decoration: InputDecoration(labelText: "คำอธิบาย (Description)", prefixIcon: Icon(Icons.description)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("ยกเลิก")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  await user?.updateDisplayName(_nameController.text);
                  await user?.reload();
                }
                setState(() => _myDescription = _descController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ บันทึกข้อมูลโปรไฟล์เรียบร้อยแล้ว!"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1), 
                  ),
                );
              },
              child: Text("บันทึก"),
            ),
          ],
        );
      },
    );
  }

  // --- 3. ฟังก์ชันหน้าต่างกรอกรายละเอียดห้องน้ำ แล้วเซฟลง Firestore ---
  // --- ฟังก์ชันหน้าต่างกรอกรายละเอียดห้องน้ำ (เวอร์ชันจัดเต็ม) ---
  // --- ฟังก์ชันหน้าต่างกรอกรายละเอียดห้องน้ำ (เวอร์ชันมีรูปภาพ) ---
  void _showAddToiletDialog() {
    TextEditingController detailController = TextEditingController();
    
    bool isFree = true;
    String paymentMethod = 'เงินสด';
    String toiletStyle = 'ชักโครก';
    int rating = 5;
    bool hasTissue = false;
    bool hasBidet = false;
    bool hasSoap = false;

    // --- ตัวแปรใหม่สำหรับจัดการรูปภาพ ---
    File? selectedImage; // เก็บไฟล์รูปภาพที่เลือก
    bool isUploading = false; // เช็คว่ากำลังส่งข้อมูลอยู่ไหม (จะได้โชว์วงล้อโหลด)

    showDialog(
      context: context,
      barrierDismissible: false, // ป้องกันการเผลอกดปิดหน้าต่างตอนกำลังอัปโหลดรูป
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("📍 ข้อมูลห้องน้ำ", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Container(
                width: double.maxFinite, // <--- เพิ่มตรงนี้! บังคับความกว้างไม่ให้ค่ามันรวน
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. ประเภทห้องน้ำ
                    Text("ประเภทห้องน้ำ:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text("ฟรี"),
                          selected: isFree == true,
                          onSelected: (val) => setDialogState(() => isFree = true),
                        ),
                        SizedBox(width: 10),
                        ChoiceChip(
                          label: Text("เสียเงิน"),
                          selected: isFree == false,
                          onSelected: (val) => setDialogState(() => isFree = false),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // 1.1 ประเภทการจ่ายเงิน (สไลด์ลงมาสมูทๆ)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: isFree 
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("การชำระเงิน:", style: TextStyle(fontWeight: FontWeight.bold)),
                                Wrap(
                                  spacing: 8,
                                  children: ['เงินสด', 'สแกนจ่าย', 'ทั้งสองอย่าง'].map((method) {
                                    return ChoiceChip(
                                      label: Text(method),
                                      selected: paymentMethod == method,
                                      onSelected: (val) => setDialogState(() => paymentMethod = method),
                                    );
                                  }).toList(),
                                ),
                                SizedBox(height: 10),
                              ],
                            ),
                    ),

                    // 2. สไตล์ห้องน้ำ
                    Text("สไตล์ห้องน้ำ:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: ['ชักโครก', 'นั่งยอง'].map((style) {
                        return ChoiceChip(
                          label: Text(style),
                          selected: toiletStyle == style,
                          onSelected: (val) => setDialogState(() => toiletStyle = style),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 10),

                    // 3. ความสะอาด
                    Text("ความสะอาด:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setDialogState(() => rating = index + 1),
                          child: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 10),

                    // 4. สิ่งอำนวยความสะดวก
                    Text("สิ่งอำนวยความสะดวก:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(label: Text("กระดาษทิชชู่"), selected: hasTissue, onSelected: (val) => setDialogState(() => hasTissue = val)),
                        FilterChip(label: Text("สายชำระ"), selected: hasBidet, onSelected: (val) => setDialogState(() => hasBidet = val)),
                        FilterChip(label: Text("สบู่ล้างมือ"), selected: hasSoap, onSelected: (val) => setDialogState(() => hasSoap = val)),
                      ],
                    ),
                    SizedBox(height: 15),

                    // 5. รายละเอียดเพิ่มเติม
                    TextField(
                      controller: detailController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "รายละเอียดเพิ่มเติม (ถ้ามี)",
                        hintText: "เช่น อยู่ชั้น 1 ติดบันไดเลื่อน",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 15),

                    // --- 6. ปุ่มเลือกรูปภาพ ---
                    Text("รูปภาพห้องน้ำ:", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Center(
                      child: selectedImage != null
                          ? Stack( // ถ้ามีรูปแล้ว ให้โชว์รูปพร้อมปุ่มกากบาทลบทิ้ง
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                                ),
                                IconButton(
                                  icon: Icon(Icons.cancel, color: Colors.red, size: 30),
                                  onPressed: () => setDialogState(() => selectedImage = null), // กดลบรูประหว่างรอส่งได้
                                ),
                              ],
                            )
                          : OutlinedButton.icon( // ถ้ายังไม่มีรูป ให้โชว์ปุ่มเลือก
                              icon: Icon(Icons.photo_library),
                              label: Text("เลือกรูปจากแกลเลอรี่"),
                              onPressed: () async {
                                final picker = ImagePicker();
                                // บีบอัดรูปนิดนึง (quality: 70) จะได้ส่งขึ้นฟ้าไวๆ ครับ
                                final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70); 
                                if (pickedFile != null) {
                                  setDialogState(() {
                                    selectedImage = File(pickedFile.path); // เอารูปมาเก็บไว้ในตัวแปร
                                  });
                                }
                              },
                            ),
                    ),
                    // ------------------------
                  ],
                ),
              ),
            ),
              actions: [
                if (!isUploading) // ซ่อนปุ่มยกเลิกตอนกำลังส่งรูป
                  TextButton(onPressed: () => Navigator.pop(context), child: Text("ยกเลิก", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                  // ถ้ากำลังอัปโหลดอยู่ จะล็อคปุ่ม (เป็น null) ไม่ให้กดซ้ำ
                  onPressed: isUploading ? null : () async {
                    setDialogState(() => isUploading = true); // สั่งให้หน้าจอขึ้นวงล้อหมุนๆ
                    
                    String? imageUrl;
                    final user = FirebaseAuth.instance.currentUser;

                    try {
                      // ขั้นตอนที่ 1: ถ้ายูสเซอร์เลือกรูป ให้ส่งรูปขึ้น Firebase Storage ก่อน
                      if (selectedImage != null) {
                        String fileName = 'toilets/${DateTime.now().millisecondsSinceEpoch}.jpg'; // ตั้งชื่อรูปไม่ให้ซ้ำกัน
                        Reference ref = FirebaseStorage.instance.ref().child(fileName);
                        UploadTask uploadTask = ref.putFile(selectedImage!);
                        TaskSnapshot snapshot = await uploadTask;
                        imageUrl = await snapshot.ref.getDownloadURL(); // ได้ลิงก์ URL ของรูปมาแล้ว!
                      }

                      // ขั้นตอนที่ 2: ส่งข้อมูลห้องน้ำ (พร้อม URL รูป) ไปที่ Firestore
                      await FirebaseFirestore.instance.collection('toilets').add({
                        'latitude': _currentMapCenter.latitude,
                        'longitude': _currentMapCenter.longitude,
                        'isFree': isFree,
                        'paymentMethod': isFree ? null : paymentMethod,
                        'toiletStyle': toiletStyle,
                        'ratings': {
                          user?.uid ?? 'anonymous': rating // เก็บเป็นกล่องรายชื่อว่าใครให้กี่ดาว
                        },
                        'amenities': {
                          'hasTissue': hasTissue,
                          'hasBidet': hasBidet,
                          'hasSoap': hasSoap,
                        },
                        'description': detailController.text,
                        'imageUrl': imageUrl, // <--- เอา URL รูปภาพมาใส่ตรงนี้!
                        'status': 'pending', 
                        'authorName': user?.displayName ?? 'Anonymous Hero',
                        'authorId': user?.uid,
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      Navigator.pop(context); // ปิด popup
                      setState(() => _isPinningMode = false); // ออกจากโหมดเล็งเป้า

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("✅ ส่งข้อมูลให้แอดมินตรวจสอบแล้ว!"), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      setDialogState(() => isUploading = false); // ถ้าพังให้หยุดวงล้อ
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("❌ เกิดข้อผิดพลาด: $e"), backgroundColor: Colors.red),
                      );
                    }
                  },
                  // โชว์วงล้อโหลด ถ้า isUploading เป็น true
                  child: isUploading 
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("ยืนยันพิกัด", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }
  // -------------------------------------------------------------

  Widget _buildMenuButton({required IconData icon, required VoidCallback onPressed, bool isBig = false}) {
    return Container(
      width: isBig ? 60 : 60,
      height: isBig ? 60 : 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Icon(icon, size: isBig ? 40 : 30, color: Colors.brown),
        ),
      ),
    );
  }

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email == 'admintoilet0012@gmail.com';
    final isGuest = user?.isAnonymous ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hero Map", style: TextStyle(fontSize: 18)),
            Text(user?.displayName ?? "Anonymous Hero", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
          ],
        ),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPage()),
                );
              },
              icon: Icon(Icons.admin_panel_settings, color: Colors.amber), // ไอคอนโล่สีทอง
            ),
            
            IconButton(onPressed: () => logout(context), icon: Icon(Icons.logout))
            ],
          ),
      body: Stack(
        children: [
          // 1. แผนที่ Google Map
          GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: _defaultLocation,
            
            // --- เพิ่มบรรทัดนี้เข้าไปเพื่อปิดปุ่มนำทางของ Google ---
            mapToolbarEnabled: false, 
            // ---------------------------------------------
            
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // ปิดปุ่มเป้าหมายขวาบน
            markers: _markers,
            onCameraMove: (CameraPosition position) {
              _currentMapCenter = position.target;
            },
          ),

          // --- 2. เป้าเล็งสีแดงตรงกลางจอ (จะโชว์ก็ต่อเมื่อกดโหมดเล็งเป้า) ---
          if (_isPinningMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0), // ดันขึ้นนิดนึงให้ปลายหมุดแตะตรงกลางพอดี
                child: Icon(Icons.location_on, size: 50, color: Colors.red),
              ),
            ),
          // -------------------------------------------------------

          // 3. ช่องค้นหา (โชว์เฉพาะตอนไม่ได้เล็งเป้า)
          if (!_isPinningMode)
            Positioned(
              top: 20,
              left: 15,
              right: 15,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _searchPlace(),
                  decoration: InputDecoration(
                    hintText: "ค้นหาสถานที่...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(left: 20, top: 15),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search, color: Colors.brown),
                      onPressed: () {
                        _searchPlace();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                ),
              ),
            ),

          if (!_isPinningMode) // ซ่อนปุ่มนี้ตอนกำลังอยู่ในโหมดเล็งเป้า
            Positioned(
              bottom: 105, // ปรับตัวเลขตรงนี้ให้อยู่เหนือปุ่ม +/- ได้ตามใจชอบเลยครับ
              right: 6,
              child: FloatingActionButton(
                heroTag: "myLocationBtn", // กันบั๊กปุ่มซ้ำ
                mini: true, // ทำให้ปุ่มไซส์เล็กลงกำลังดี
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent, // ใช้สีฟ้าให้เหมือนของ Google
                onPressed: () {
                  _determinePosition(); // เรียกฟังก์ชันเดิมให้กล้องบินกลับมาหาเรา!
                },
                child: Icon(Icons.my_location),
              ),
            ),

          // 4. แถบปุ่มด้านล่าง
          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // --- ถ้าอยู่ในโหมดเล็งเป้า จะโชว์ปุ่ม "ยกเลิก" และ "ยืนยัน" ---
                if (_isPinningMode) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                    onPressed: () => setState(() => _isPinningMode = false),
                    child: Text("ยกเลิก", style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown, 
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15)
                    ),
                    onPressed: () {
                      _showAddToiletDialog(); // เรียกหน้าต่างกรอกข้อมูล
                    },
                    child: Text("เล็งตรงนี้แหละ!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ] 
                // --- ถ้าไม่ได้เล็งเป้า โชว์ 3 ปุ่มปกติ ---
                else ...[
                  _buildMenuButton(
                    icon: Icons.layers,
                    onPressed: () => _toggleMapType(),
                  ),
                  if (!isGuest)
                    _buildMenuButton(
                      icon: Icons.add_location_alt,
                      isBig: true,
                      onPressed: () {
                        // กดแล้วเข้าสู่โหมดเล็งเป้า
                        setState(() {
                          _isPinningMode = true; 
                        });
                      },
                    ),
                  if (!isGuest)
                    _buildMenuButton(
                      icon: Icons.person,
                      onPressed: () => _showProfileDialog(),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}