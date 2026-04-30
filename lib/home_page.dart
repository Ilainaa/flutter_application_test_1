// นำเข้าไลบรารีที่จำเป็นสำหรับแอปพลิเคชัน
import 'dart:async'; // สำหรับ Stream, Completer
import 'package:firebase_auth/firebase_auth.dart'; // สำหรับการจัดการผู้ใช้ Firebase
import 'package:flutter/material.dart'; // สำหรับสร้าง UI ด้วย Flutter
import 'package:google_maps_flutter/google_maps_flutter.dart'; // สำหรับแสดง Google Maps
import 'package:geolocator/geolocator.dart'; // สำหรับการเข้าถึงตำแหน่งปัจจุบันของผู้ใช้
import 'package:geocoding/geocoding.dart'; // สำหรับการแปลงที่อยู่เป็นพิกัดและกลับกัน
import 'package:cloud_firestore/cloud_firestore.dart'; // สำหรับการเชื่อมต่อกับ Firebase Firestore (ฐานข้อมูล)
import 'dart:io'; // สำหรับการจัดการไฟล์ (เช่น รูปภาพ)
import 'package:image_picker/image_picker.dart'; // สำหรับเลือกรูปภาพจากแกลเลอรีหรือกล้อง
import 'package:firebase_storage/firebase_storage.dart'; // สำหรับการอัปโหลดรูปภาพไปยัง Firebase Storage
import 'admin_page.dart'; // นำเข้าหน้า Admin
import 'package:url_launcher/url_launcher.dart'; // สำหรับเปิด URL ภายนอก (เช่น Google Maps สำหรับนำทาง)
import 'package:google_sign_in/google_sign_in.dart'; // สำหรับการลงชื่อเข้าใช้ด้วย Google
import 'login_page.dart'; // นำเข้าหน้า Login
import 'tutorial_dialog.dart'; // นำเข้า Dialog สอนการใช้งาน

// ── สีธีมหลัก (ใช้งานทั้งไฟล์) ──
const Color _pink = Color(0xFFE91E8C); // สีชมพูหลัก
const Color _lightPink = Color(0xFFFCE4EC); // สีชมพูอ่อน
const Color _softPink = Color(0xFFF8BBD0); // สีชมพูอมขาว
const Color _deepPink = Color(0xFFC2185B); // สีชมพูเข้ม

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Completer สำหรับควบคุม GoogleMapController เมื่อแผนที่ถูกสร้างเสร็จ
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>(); 
  final Set<Marker> _markers = {}; // Set สำหรับเก็บ Marker ทั้งหมดบนแผนที่
  MapType _currentMapType = MapType.normal; // ประเภทของแผนที่ (Normal, Hybrid)
  final TextEditingController _searchController = TextEditingController(); // Controller สำหรับช่องค้นหาสถานที่

  String _myDescription = ""; // คำอธิบายส่วนตัวของผู้ใช้ (ยังไม่ได้ใช้ในโค้ดนี้)
  final TextEditingController _nameController = TextEditingController(); // Controller สำหรับชื่อผู้ใช้ใน Profile Dialog
  final TextEditingController _descController = TextEditingController(); // Controller สำหรับคำอธิบายใน Profile Dialog

  bool _isPinningMode = false; // สถานะว่ากำลังอยู่ในโหมดปักหมุดหรือไม่
  LatLng _currentMapCenter = const LatLng(13.764953, 100.538316); // พิกัดกลางแผนที่ปัจจุบัน

  // ตำแหน่งเริ่มต้นของกล้องบนแผนที่
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(13.764953, 100.538316),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState(); // เรียก initState ของคลาสแม่
    _determinePosition(); // ตรวจสอบและขออนุญาตเข้าถึงตำแหน่งปัจจุบันของผู้ใช้
    _listenToApprovedToilets(); // เริ่มฟังการเปลี่ยนแปลงข้อมูลห้องน้ำจาก Firestore

    // เรียกใช้ฟังก์ชันแสดง Tutorial หลังจาก Widget ถูกสร้างเสร็จแล้ว
    // เพื่อให้แน่ใจว่า BuildContext พร้อมใช้งาน
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showTutorialIfNeeded(context);
  });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled(); // ตรวจสอบว่าเปิด GPS หรือไม่
    if (!serviceEnabled) return; // ถ้าไม่ได้เปิด GPS ให้หยุดทำงาน

    LocationPermission permission = await Geolocator.checkPermission(); // ตรวจสอบสิทธิ์การเข้าถึงตำแหน่ง
    if (permission == LocationPermission.denied) { // ถ้ายังไม่ได้รับอนุญาต
      permission = await Geolocator.requestPermission(); // ขออนุญาตเข้าถึงตำแหน่ง
      if (permission == LocationPermission.denied) return; // ถ้าผู้ใช้ปฏิเสธ ให้หยุดทำงาน
    }

    Position position = await Geolocator.getCurrentPosition(); // รับตำแหน่งปัจจุบัน
    final GoogleMapController controller = await _controller.future; // รอให้ GoogleMapController พร้อมใช้งาน
    controller.animateCamera(CameraUpdate.newCameraPosition( // ย้ายกล้องไปยังตำแหน่งปัจจุบัน
      CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 17), // ตั้งค่าพิกัดและซูม
    ));
  }

  // สลับประเภทของแผนที่ระหว่าง Normal และ Hybrid
  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
  }

  // ค้นหาสถานที่จากข้อความที่ผู้ใช้ป้อน
  Future<void> _searchPlace() async {
    String query = _searchController.text.trim(); // รับข้อความค้นหาและตัดช่องว่าง
    if (query.isEmpty) return; // ถ้าข้อความว่างเปล่า ให้หยุดทำงาน
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
      _showSnackBar("หาสถานที่ไม่เจอ ลองพิมพ์ให้ชัดเจนขึ้นนะคะ", isError: true); // แสดง SnackBar แจ้งเตือน
    }
  }

  // ฟังก์ชันเปิดแอป Google Maps เพื่อนำทาง
  Future<void> _navigateToToilet(double lat, double lng) async {
    // 1. สร้างลิงก์คำสั่ง (URI) โดยแนบพิกัดละติจูดและลองจิจูดไปที่ปลายทาง (destination)
    // travelmode=driving คือการนำทางด้วยรถยนต์
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    // 2. เช็คว่ามือถือเครื่องนี้สามารถเปิดลิงก์นี้ได้ไหม? (มีแอปหรือเบราว์เซอร์รองรับไหม)
    if (await canLaunchUrl(googleMapsUrl)) {
      // ถ้าเปิดได้ ให้ทำการ Launch เลย โดยบังคับให้เปิดเป็นแอปภายนอก
      await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      // 3. ถ้าเปิดไม่ได้ (เช่น ไม่มีแอป) ให้โชว์แจ้งเตือน
      _showSnackBar("ไม่สามารถเปิดระบบนำทางได้ครับ", isError: true);
    }
  }

  // แสดง SnackBar สำหรับแจ้งเตือนผู้ใช้
  void _showSnackBar(String msg, {bool isError = false, bool isSuccess = false}) {
    Color bg = isError ? _deepPink : (isSuccess ? Colors.green : _pink); // กำหนดสีพื้นหลังตามประเภทข้อความ
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: bg, // สีพื้นหลัง
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  // ฟังการเปลี่ยนแปลงข้อมูลห้องน้ำจาก Firestore และอัปเดต Marker บนแผนที่
  void _listenToApprovedToilets() {
    final user = FirebaseAuth.instance.currentUser; // ผู้ใช้ปัจจุบัน
    final isAdmin = user?.email == 'admintoilet0012@gmail.com'; // ตรวจสอบว่าเป็น Admin หรือไม่

    // 1. สร้างคำสั่งดึงข้อมูล
    Query query = FirebaseFirestore.instance.collection('toilets'); // อ้างอิงไปยังคอลเลกชัน 'toilets'
    
    // ถ้า "ไม่ใช่" แอดมิน ให้ดึงมาโชว์เฉพาะที่อนุมัติแล้ว (approved)
    // แต่ถ้าเป็นแอดมิน มันจะไม่เข้า if นี้ และดึงมาทั้งหมด (รวม pending ด้วย)
    if (!isAdmin) {
      query = query.where('status', isEqualTo: 'approved'); // กรองเฉพาะห้องน้ำที่อนุมัติแล้ว
    }

    query.snapshots().listen((snapshot) { // ฟังการเปลี่ยนแปลงของ Query
      Set<Marker> newMarkers = {}; // สร้าง Set ใหม่สำหรับ Marker
      for (var doc in snapshot.docs) { // วนลูปผ่านเอกสารแต่ละฉบับ
        var data = doc.data() as Map<String, dynamic>; // แปลงข้อมูลเอกสารเป็น Map
        LatLng position = LatLng(data['latitude'], data['longitude']); // ดึงพิกัด

        String status = data['status'] ?? 'pending'; // สถานะของห้องน้ำ
        bool isFree = data['isFree'] ?? true; // ฟรีหรือไม่
        bool isBroken = data['isBroken'] ?? false; // ชำรุดหรือไม่

        String titleText; // ข้อความที่จะแสดงบน Marker
        double pinColor; // สีของ Marker

        // 2. แยกสีหมุดตามสถานะ (เพิ่มสีฟ้าสำหรับแอดมิน)
        if (status == 'pending') {
          titleText = '⏳ รอตรวจสอบ (Pending)';
          pinColor = BitmapDescriptor.hueCyan; 
        } else if (isBroken) {
          titleText = '❌ ชำรุด / ปิดซ่อมแซม';
          pinColor = BitmapDescriptor.hueRed;
        } else if (isFree) {
          titleText = '🆓 ห้องน้ำฟรี';
          pinColor = BitmapDescriptor.hueGreen;
        } else {
          titleText = '💰 ห้องน้ำเสียเงิน';
          pinColor = BitmapDescriptor.hueOrange;
        }

        newMarkers.add(Marker( // เพิ่ม Marker ใหม่
          markerId: MarkerId(doc.id), // ID ของ Marker คือ ID ของเอกสาร
          position: position, // ตำแหน่งของ Marker
          onTap: () => _showToiletDetails(doc.id, data), // เมื่อแตะ Marker ให้แสดงรายละเอียด
          icon: BitmapDescriptor.defaultMarkerWithHue(pinColor), // ไอคอน Marker พร้อมสี
        ));
      }
      
      // อัปเดตหน้าจอ
      if (mounted) {
        setState(() {
          _markers.clear(); // ล้าง Marker เก่าทั้งหมด
          _markers.addAll(newMarkers); // เพิ่ม Marker ใหม่ทั้งหมด
        });
      }
    });
  }

  // แสดง Modal Bottom Sheet สำหรับรายละเอียดห้องน้ำ
  void _showToiletDetails(String docId, Map<String, dynamic> data) {
    bool isFree = data['isFree'] ?? true; // สถานะฟรีหรือไม่
    bool isBroken = data['isBroken'] ?? false; // สถานะชำรุดหรือไม่
    Map<String, dynamic> amenities = data['amenities'] ?? {}; // สิ่งอำนวยความสะดวก

    final currentUser = FirebaseAuth.instance.currentUser; // ผู้ใช้ปัจจุบัน
    final String myUid = currentUser?.uid ?? 'anonymous'; // UID ของผู้ใช้
    final bool isGuest = FirebaseAuth.instance.currentUser == null; // เป็น Guest หรือไม่

    Map<String, dynamic> ratings = data['ratings'] != null
        ? Map<String, dynamic>.from(data['ratings'])
        : {};

    if (ratings.isEmpty && data['rating'] != null) {
      ratings['legacy'] = data['rating'];
    }

    showModalBottomSheet(
      context: context, // BuildContext
      isScrollControlled: true, // ทำให้ Bottom Sheet สามารถขยายเต็มหน้าจอได้
      backgroundColor: Colors.transparent, // พื้นหลังโปร่งใส
      builder: (context) { // Builder สำหรับเนื้อหาของ Bottom Sheet
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double avgRating = 0.0;
            int totalVotes = ratings.length;
            if (totalVotes > 0) {
              double sum = 0;
              ratings.values.forEach((val) => sum += (val as num).toDouble());
              avgRating = sum / totalVotes;
            }
            int myCurrentRating = ratings[myUid] ?? 0;

            return Container(
              decoration: const BoxDecoration( // ตกแต่ง Container
                color: Colors.white, // สีพื้นหลัง
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)), // ขอบโค้งด้านบน
              ),
              padding: EdgeInsets.only(
                left: 24, // ระยะห่างด้านซ้าย
                right: 24, // ระยะห่างด้านขวา
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── แถบลาก ──
                    Center(
                      child: Container( // แถบลากด้านบนของ Bottom Sheet
                        width: 44, // ความกว้าง
                        height: 5, // ความสูง
                        margin: const EdgeInsets.only(bottom: 18), // ระยะห่างด้านล่าง
                        decoration: BoxDecoration( // ตกแต่ง
                          color: _softPink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // ── รูปภาพ ──
                    if (data['imageUrl'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          data['imageUrl'],
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── ส่วนหัว + ดาว ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container( // แสดงสถานะห้องน้ำ (ฟรี/เสียเงิน/ชำรุด)
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // ระยะห่างภายใน
                            decoration: BoxDecoration( // ตกแต่ง
                              color: isBroken
                                  ? const Color(0xFFFFEBEE) // สีพื้นหลังตามสถานะ
                                  : (isFree ? const Color(0xFFE8F5E9) : _lightPink),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isBroken
                                  ? '❌ ปิดซ่อมแซม'
                                  : (isFree ? '🆓 ห้องน้ำเข้าฟรี' : '💰 ห้องน้ำเสียเงิน'),
                              style: TextStyle( // สไตล์ข้อความ
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isBroken
                                    ? Colors.red[700]
                                    : (isFree ? Colors.green[700] : _deepPink),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [ // แสดงคะแนนเฉลี่ย
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 26), // ไอคอนดาว
                            const SizedBox(width: 4), // ระยะห่าง
                            Text( // ข้อความคะแนน
                              "${avgRating.toStringAsFixed(1)} ($totalVotes)",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── ข้อมูลพื้นฐาน ──
                    _infoRow(Icons.wc_rounded, _pink, "สไตล์: ${data['toiletStyle'] ?? 'ไม่ระบุ'}"), // แสดงสไตล์ห้องน้ำ
                    if (!isFree && data['paymentMethod'] != null) ...[
                      const SizedBox(height: 8), // ระยะห่าง
                      _infoRow(Icons.payment_rounded, Colors.green, "รับชำระ: ${data['paymentMethod']}"), // แสดงวิธีการชำระเงิน
                    ],
                    const SizedBox(height: 16),

                    // ── สิ่งอำนวยความสะดวก ──
                    const Text("✨ สิ่งอำนวยความสะดวก",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _deepPink)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [ // แสดง Chip สิ่งอำนวยความสะดวก
                        if (amenities['hasTissue'] == true) // ถ้ามีทิชชู่
                          _amenityChip("🧻 ทิชชู่"), // แสดง Chip ทิชชู่
                        if (amenities['hasBidet'] == true) // ถ้ามีสายชำระ
                          _amenityChip("🚿 สายชำระ"), // แสดง Chip สายชำระ
                        if (amenities['hasSoap'] == true) // ถ้ามีสบู่
                          _amenityChip("🧼 สบู่"), // แสดง Chip สบู่
                        if (amenities['hasTissue'] != true &&
                            amenities['hasBidet'] != true && // ถ้าไม่มีสิ่งอำนวยความสะดวกใดๆ
                            amenities['hasSoap'] != true)
                          Text("- ไม่มีข้อมูล -",
                              style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── รายละเอียด ──
                    const Text("📝 รายละเอียดเพิ่มเติม",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _deepPink)),
                    const SizedBox(height: 6),
                    Text( // แสดงรายละเอียดเพิ่มเติม
                      data['description'] != "" && data['description'] != null
                          ? data['description']
                          : 'ไม่ได้ระบุรายละเอียดเพิ่มเติมไว้ค่ะ', // ข้อความเริ่มต้นถ้าไม่มีรายละเอียด
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),

                    Divider(color: _lightPink, thickness: 1.5),
                    const SizedBox(height: 12),

                    // ── ให้คะแนน ──
                    if (!isGuest) ...[
                      const Text("⭐ ให้คะแนนห้องน้ำนี้", // หัวข้อให้คะแนน
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _deepPink)),
                      const SizedBox(height: 8),
                      Row( // แถบดาวสำหรับให้คะแนน
                        children: List.generate(5, (index) {
                          int starValue = index + 1;
                          return GestureDetector(
                            onTap: () async {
                              setSheetState(() => ratings[myUid] = starValue);
                              await FirebaseFirestore.instance
                                  .collection('toilets')
                                  .doc(docId)
                                  .update({'ratings.$myUid': starValue}); // อัปเดตคะแนนใน Firestore
                            },
                            child: Icon(
                              starValue <= myCurrentRating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: 38,
                            ),
                          );
                        }),
                      ),
                    ] else ...[
                      Container( // ข้อความแจ้งเตือนสำหรับ Guest
                        padding: const EdgeInsets.all(12), // ระยะห่างภายใน
                        decoration: BoxDecoration( // ตกแต่ง
                          color: _lightPink, // สีพื้นหลัง
                          borderRadius: BorderRadius.circular(14), // ขอบโค้ง
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_rounded, color: _pink, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "เข้าสู่ระบบแบบสมาชิกเพื่อร่วมให้คะแนน",
                                style: TextStyle(color: _deepPink, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],


                  // --- ปุ่มนำทาง ---
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon( // ปุ่มนำทาง
                      icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 24), // ไอคอน
                      label: const Text("นำทางไปห้องน้ำนี้", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // ข้อความ
                      style: ElevatedButton.styleFrom( // สไตล์ปุ่ม
                        backgroundColor: Colors.blueAccent, // สีพื้นหลัง
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        // ปิดหน้าต่าง Popup ก่อนเพื่อความสวยงาม
                        Navigator.pop(context); 
                        
                        // เรียกใช้งานฟังก์ชันนำทาง พร้อมส่งพิกัดของหมุดนี้ไปให้
                        _navigateToToilet(data['latitude'], data['longitude']);
                      },
                    ),
                  ),
                  // ------------------

                    // ── ปุ่มรายงาน ──
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, // ความกว้างเต็มพื้นที่
                      child: OutlinedButton.icon( // ปุ่มรายงานปัญหา
                        icon: const Icon(Icons.flag_rounded, color: _deepPink), // ไอคอน
                        label: const Text("รายงานปัญหา / แจ้งหมุดไม่ถูกต้อง",
                            style: TextStyle(color: _deepPink, fontWeight: FontWeight.w600)), // ข้อความ
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _softPink, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          backgroundColor: _lightPink.withOpacity(0.3),
                        ),
                        onPressed: () {
                          if (isGuest) { // ถ้าเป็น Guest
                            showDialog(
                              context: context,
                              builder: (ctx) => _buildPinkDialog(
                                ctx,
                                title: "🔒 แจ้งเตือน",
                                content: "ฟังก์ชันนี้สงวนไว้สำหรับสมาชิกค่ะ\nกรุณาเข้าสู่ระบบเพื่อร่วมรายงานปัญหา",
                                onConfirm: () => Navigator.pop(ctx),
                                confirmLabel: "ตกลง",
                              ),
                            );
                          } else {
                            _showReportDialog(docId); // แสดง Dialog รายงานปัญหา
                          }
                        },
                      ),
                    ),

                    Row(
                      children: [
                        Icon(Icons.person_rounded, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 5),
                        Text(
                          "ปักหมุดโดย: ${data['authorName'] ?? 'Anonymous Hero'}",
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Widget สำหรับแสดงข้อมูลเป็นแถวพร้อมไอคอน
  Widget _infoRow(IconData icon, Color color, String text) {
    return Row(
      children: [ // ไอคอน, ระยะห่าง, ข้อความ
        Icon(icon, color: color, size: 20), // ไอคอน
        const SizedBox(width: 8), // ระยะห่าง
        Text(text, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget _amenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // ระยะห่างภายใน
      decoration: BoxDecoration( // ตกแต่ง
        color: _lightPink, // สีพื้นหลัง
        borderRadius: BorderRadius.circular(20), // ขอบโค้ง
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, color: _deepPink)),
    );
  }

  // ── Dialog สไตล์ชมพู ──
  Widget _buildPinkDialog(
    BuildContext ctx, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
    required String confirmLabel,
    VoidCallback? onCancel,
  }) {
    return AlertDialog( // Dialog แจ้งเตือน
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), // ขอบโค้ง
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0), // ระยะห่าง Title
      title: Text(title, // Title
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: _deepPink, fontSize: 18)),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0), // ระยะห่าง Content
      content: Text(content, style: TextStyle(color: Colors.grey[700], height: 1.5)), // เนื้อหา
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // ระยะห่าง Actions
      actions: [ // ปุ่มต่างๆ
        if (onCancel != null) // ถ้ามีปุ่มยกเลิก
          TextButton( // ปุ่มยกเลิก
            onPressed: onCancel, // ฟังก์ชันเมื่อกด
            child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[500])), // ข้อความ
          ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _pink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // แสดง Dialog สำหรับรายงานปัญหาห้องน้ำ
  void _showReportDialog(String toiletId) {
    TextEditingController reportController = TextEditingController(); // Controller สำหรับข้อความรายงาน
    bool isSubmitting = false; // สถานะการส่งข้อมูล

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), // ขอบโค้ง
              title: Row( // Title ของ Dialog
                children: [
                  Container( // ไอคอน
                    padding: const EdgeInsets.all(8), // ระยะห่างภายใน
                    decoration: BoxDecoration(
                      color: _lightPink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.flag_rounded, color: _deepPink, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text("รายงานปัญหา",
                      style: TextStyle(
                          color: _deepPink, fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
              content: Column( // เนื้อหาของ Dialog
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("พบปัญหาอะไรเกี่ยวกับห้องน้ำนี้คะ?", // ข้อความ
                      style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reportController,
                    maxLines: 3,
                    style: const TextStyle(color: Color(0xFF4A0020)),
                    decoration: InputDecoration(
                      hintText: "เช่น ชำรุด, สกปรกมาก, ปิดถาวร...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: _lightPink.withOpacity(0.4),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _softPink),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _pink, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                if (!isSubmitting) // ถ้ายังไม่ได้กำลังส่งข้อมูล
                  TextButton( // ปุ่มยกเลิก
                    onPressed: () => Navigator.pop(context), // ปิด Dialog
                    child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[500])), // ข้อความ
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async { // ฟังก์ชันเมื่อกดส่งรายงาน
                          if (reportController.text.trim().isEmpty) { // ตรวจสอบว่ากรอกข้อมูลหรือไม่
                            _showSnackBar("กรุณากรอกรายละเอียดปัญหาก่อนส่งค่ะ",
                                isError: true); // แจ้งเตือน
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final user = FirebaseAuth.instance.currentUser;
                          try {
                            await FirebaseFirestore.instance
                                .collection('reports')
                                .add({
                              'toiletId': toiletId,
                              'reason': reportController.text.trim(),
                              'reporterId': user?.uid,
                              'reporterName':
                                  user?.displayName ?? 'Anonymous Hero',
                              'timestamp': FieldValue.serverTimestamp(),
                              'status': 'pending',
                            });

                            await FirebaseFirestore.instance.collection('toilets').doc(toiletId).update({ // อัปเดตสถานะห้องน้ำเป็นชำรุด
                              'isBroken': true,
                            });
                            Navigator.pop(context); // ปิด Dialog
                            _showSnackBar("✅ ขอบคุณที่ช่วยรายงานค่ะ แอดมินจะรีบตรวจสอบ!",
                                isSuccess: true);
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar("❌ เกิดข้อผิดพลาด: $e", isError: true);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("ส่งรายงาน",
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // แสดง Dialog สำหรับตั้งค่าโปรไฟล์ผู้ใช้
  void _showProfileDialog() {
    final user = FirebaseAuth.instance.currentUser; // ผู้ใช้ปัจจุบัน
    _nameController.text = user?.displayName ?? ""; // ตั้งค่าชื่อเริ่มต้น
    _descController.text = _myDescription; // ตั้งค่าคำอธิบายเริ่มต้น
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _lightPink, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_rounded, color: _pink, size: 20),
              ),
              const SizedBox(width: 10),
              const Text("ตั้งค่าโปรไฟล์",
                  style: TextStyle(
                      color: _deepPink, fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField( // ช่องกรอกชื่อ
                  controller: _nameController, // Controller
                  label: "ชื่อของคุณ",
                  icon: Icons.person_rounded),
              const SizedBox(height: 14)
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton( // ปุ่มยกเลิก
              onPressed: () => Navigator.pop(context), // ปิด Dialog
              child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[500])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async { // ฟังก์ชันเมื่อกดบันทึก
                if (_nameController.text.isNotEmpty) { // ถ้ามีการกรอกชื่อ
                  await user?.updateDisplayName(_nameController.text); // อัปเดตชื่อผู้ใช้
                  await user?.reload(); // โหลดข้อมูลผู้ใช้ใหม่
                }
                setState(() => _myDescription = _descController.text);
                Navigator.pop(context);
                _showSnackBar("✅ บันทึกข้อมูลโปรไฟล์เรียบร้อยแล้ว!",
                    isSuccess: true);
              },
              child: const Text("บันทึก",
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // Widget สำหรับ TextField ใน Dialog
  Widget _dialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF4A0020)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.pink[300]),
        prefixIcon: Icon(icon, color: _pink),
        filled: true,
        fillColor: _lightPink.withOpacity(0.35),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _softPink),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _pink, width: 2),
        ),
      ),
    );
  }

  // แสดง Dialog สำหรับเพิ่มข้อมูลห้องน้ำใหม่
  void _showAddToiletDialog() {
    TextEditingController detailController = TextEditingController(); // Controller สำหรับรายละเอียด

    bool isFree = true; // สถานะฟรีหรือไม่
    String paymentMethod = 'เงินสด'; // วิธีการชำระเงิน
    String toiletStyle = 'ชักโครก'; // สไตล์ห้องน้ำ
    int rating = 5; // คะแนนเริ่มต้น
    bool hasTissue = false; // มีทิชชู่หรือไม่
    bool hasBidet = false; // มีสายชำระหรือไม่
    bool hasSoap = false; // มีสบู่หรือไม่
    File? selectedImage; // รูปภาพที่เลือก
    bool isUploading = false; // สถานะการอัปโหลด

    showDialog(
      context: context, // BuildContext
      barrierDismissible: false, // ป้องกันการปิด Dialog โดยการแตะนอกพื้นที่
      builder: (context) { // Builder สำหรับเนื้อหา Dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), // ระยะห่างภายใน
                    decoration: BoxDecoration( // ตกแต่ง
                        color: _lightPink, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_location_alt_rounded,
                        color: _pink, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text("📍 ข้อมูลห้องน้ำ",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _deepPink,
                          fontSize: 17)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column( // เนื้อหา Dialog
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 14),

                      // ── ประเภทห้องน้ำ ──
                      _sectionLabel("ประเภทห้องน้ำ"), // หัวข้อ
                      const SizedBox(height: 8),
                      Row( // ปุ่มเลือกประเภทห้องน้ำ
                        children: [
                          _choiceBtn("ฟรี", isFree == true, () => setDialogState(() => isFree = true)), // ปุ่มฟรี
                          const SizedBox(width: 10), // ระยะห่าง
                          _choiceBtn("เสียเงิน", isFree == false, () => setDialogState(() => isFree = false)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: isFree
                            ? const SizedBox.shrink() // ถ้าฟรี ไม่ต้องแสดงส่วนนี้
                            : Column( // ถ้าเสียเงิน แสดงส่วนวิธีการชำระเงิน
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionLabel("การชำระเงิน"), // หัวข้อ
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: ['เงินสด', 'สแกนจ่าย', 'ทั้งสองอย่าง']
                                        .map((m) => _choiceBtn(m, paymentMethod == m,
                                            () => setDialogState(() => paymentMethod = m)))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                      ),

                      // ── สไตล์ห้องน้ำ ──
                      _sectionLabel("สไตล์ห้องน้ำ"), // หัวข้อ
                      const SizedBox(height: 8),
                      Wrap( // ปุ่มเลือกสไตล์ห้องน้ำ
                        spacing: 8, // ระยะห่างระหว่างปุ่ม
                        children: ['ชักโครก', 'นั่งยอง']
                            .map((s) => _choiceBtn(s, toiletStyle == s,
                                () => setDialogState(() => toiletStyle = s)))
                            .toList(),
                      ),
                      const SizedBox(height: 10),

                      // ── ดาว ──
                      _sectionLabel("ความสะอาด"), // หัวข้อ
                      const SizedBox(height: 6),
                      Row( // แถบดาวสำหรับให้คะแนนความสะอาด
                        children: List.generate(5, (i) { // สร้างดาว 5 ดวง
                          return GestureDetector(
                            onTap: () => setDialogState(() => rating = i + 1),
                            child: Icon(
                              i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: 34,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),

                      // ── สิ่งอำนวยความสะดวก ──
                      _sectionLabel("สิ่งอำนวยความสะดวก"), // หัวข้อ
                      const SizedBox(height: 8),
                      Wrap( // Chip สิ่งอำนวยความสะดวก
                        spacing: 8, // ระยะห่างระหว่าง Chip
                        runSpacing: 6,
                        children: [
                          _filterChip("🧻 ทิชชู่", hasTissue,
                              (v) => setDialogState(() => hasTissue = v)),
                          _filterChip("🚿 สายชำระ", hasBidet,
                              (v) => setDialogState(() => hasBidet = v)),
                          _filterChip("🧼 สบู่", hasSoap,
                              (v) => setDialogState(() => hasSoap = v)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── รายละเอียดเพิ่มเติม ──
                      _sectionLabel("รายละเอียดเพิ่มเติม"), // หัวข้อ
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailController, // Controller สำหรับรายละเอียด
                        maxLines: 2,
                        style: const TextStyle(color: Color(0xFF4A0020)),
                        decoration: InputDecoration(
                          hintText: "เช่น อยู่ชั้น 1 ติดบันไดเลื่อน",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: _lightPink.withOpacity(0.35),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _softPink),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _pink, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── รูปภาพ ──
                      _sectionLabel("รูปภาพห้องน้ำ"), // หัวข้อ
                      const SizedBox(height: 8),
                      Center(
                        child: selectedImage != null // ถ้ามีรูปภาพที่เลือก
                            ? Stack( // แสดงรูปภาพและปุ่มลบ
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14), // ขอบโค้ง
                                    child: Image.file(selectedImage!, // แสดงรูปภาพจากไฟล์
                                        height: 150, // ความสูง
                                        width: double.infinity,
                                        fit: BoxFit.cover),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_rounded,
                                        color: _deepPink, size: 28),
                                    onPressed: () =>
                                        setDialogState(() => selectedImage = null),
                                  ),
                                ],
                              ) // ถ้าไม่มีรูปภาพที่เลือก
                            : GestureDetector( // ปุ่มสำหรับเลือกรูปภาพ
                                onTap: () async { // เมื่อแตะ
                                  final picker = ImagePicker(); // สร้าง ImagePicker
                                  final pickedFile = await picker.pickImage( // เลือกรูปภาพ
                                      source: ImageSource.gallery,
                                      imageQuality: 70);
                                  if (pickedFile != null) {
                                    setDialogState(
                                        () => selectedImage = File(pickedFile.path));
                                  }
                                },
                                child: Container( // UI สำหรับเลือกรูปภาพ
                                  width: double.infinity, // ความกว้างเต็มพื้นที่
                                  height: 100, // ความสูง
                                  decoration: BoxDecoration( // ตกแต่ง
                                    color: _lightPink.withOpacity(0.5), // สีพื้นหลัง
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: _softPink, width: 1.5),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.photo_library_rounded,
                                          color: _pink, size: 32),
                                      SizedBox(height: 6),
                                      Text("เลือกรูปจากแกลเลอรี่",
                                          style: TextStyle(
                                              color: _deepPink,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                if (!isUploading) // ถ้ายังไม่ได้กำลังอัปโหลด
                  TextButton( // ปุ่มยกเลิก
                    onPressed: () => Navigator.pop(context), // ปิด Dialog
                    child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[500])), // ข้อความ
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isUploading // ถ้ากำลังอัปโหลด ปุ่มจะถูกปิดใช้งาน
                      ? null // ปิดใช้งาน
                      : () async { // ฟังก์ชันเมื่อกด "ยืนยันพิกัด"
                          setDialogState(() => isUploading = true); // ตั้งค่าสถานะเป็นกำลังอัปโหลด
                          String? imageUrl; // URL รูปภาพ
                          final user = FirebaseAuth.instance.currentUser; // ผู้ใช้ปัจจุบัน

                          try {
                            if (selectedImage != null) { // ถ้ามีรูปภาพที่เลือก
                              String fileName =
                                  'toilets/${DateTime.now().millisecondsSinceEpoch}.jpg';
                              Reference ref =
                                  FirebaseStorage.instance.ref().child(fileName); // อ้างอิงถึงตำแหน่งที่จะเก็บรูปภาพใน Storage
                              UploadTask uploadTask = ref.putFile(selectedImage!);
                              TaskSnapshot snap = await uploadTask;
                              imageUrl = await snap.ref.getDownloadURL();
                            }

                            await FirebaseFirestore.instance
                                .collection('toilets')
                                .add({ // เพิ่มข้อมูลห้องน้ำใหม่ลงใน Firestore
                              'latitude': _currentMapCenter.latitude, // ละติจูด
                              'longitude': _currentMapCenter.longitude, // ลองจิจูด
                              'isFree': isFree, // ฟรีหรือไม่
                              'paymentMethod': isFree ? null : paymentMethod, // วิธีการชำระเงิน
                              'toiletStyle': toiletStyle, // สไตล์ห้องน้ำ
                              'ratings': { // คะแนน
                                user?.uid ?? 'anonymous': rating // คะแนนของผู้ใช้ปัจจุบัน
                              },
                              'amenities': { // สิ่งอำนวยความสะดวก
                                'hasTissue': hasTissue,
                                'hasBidet': hasBidet,
                                'hasSoap': hasSoap,
                              },
                              'description': detailController.text,
                              'imageUrl': imageUrl,
                              'status': 'pending',
                              'authorName':
                                  user?.displayName ?? 'Anonymous Hero',
                              'authorId': user?.uid,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            Navigator.pop(context); // ปิด Dialog
                            setState(() => _isPinningMode = false); // ออกจากโหมดปักหมุด
                            _showSnackBar("✅ ส่งข้อมูลให้แอดมินตรวจสอบแล้วค่ะ!",
                                isSuccess: true);
                          } catch (e) {
                            setDialogState(() => isUploading = false);
                            _showSnackBar("❌ เกิดข้อผิดพลาด: $e", isError: true);
                          }
                        },
                  child: isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("ยืนยันพิกัด",
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Widget สำหรับแสดงหัวข้อส่วนต่างๆ ใน Dialog
  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, color: _deepPink)); // สไตล์ข้อความ
  }

  Widget _choiceBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), // ระยะห่างภายใน
        decoration: BoxDecoration( // ตกแต่ง
          color: selected ? _pink : _lightPink.withOpacity(0.5), // สีพื้นหลังตามสถานะ selected
          borderRadius: BorderRadius.circular(20), // ขอบโค้ง
          boxShadow: selected
              ? [BoxShadow(color: _pink.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _deepPink,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, Function(bool) onSelected) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), // ระยะเวลา Animation
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // ระยะห่างภายใน
        decoration: BoxDecoration( // ตกแต่ง
          color: selected ? _pink : _lightPink.withOpacity(0.5), // สีพื้นหลังตามสถานะ selected
          borderRadius: BorderRadius.circular(20), // ขอบโค้ง
          boxShadow: selected
              ? [BoxShadow(color: _pink.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : _deepPink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับสร้างปุ่มเมนู (เช่น ปุ่มเปลี่ยน MapType, ปุ่มเพิ่มห้องน้ำ, ปุ่มโปรไฟล์)
  Widget _buildMenuButton({required IconData icon, required VoidCallback onPressed, bool isBig = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container( // Container สำหรับปุ่ม
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _pink.withOpacity(0.2),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: isBig ? 30 : 26, color: _pink), // ไอคอน
      ),
    );
  }


  void logout(BuildContext context) async {
    final isGuest = FirebaseAuth.instance.currentUser == null; // ตรวจสอบว่าเป็น Guest หรือไม่
    
    if (!isGuest) {
      // ถ้าเป็นสมาชิก ให้เคลียร์ความจำ Google และออกจากระบบ Firebase
      await GoogleSignIn().signOut(); // ออกจากระบบ Google
      await FirebaseAuth.instance.signOut(); // ออกจากระบบ Firebase
    }

    // Best Practice: เช็คว่า Widget ยังอยู่ก่อนทำคำสั่งเปลี่ยนหน้า
    if (!context.mounted) return;



    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()), // ไปยัง LoginPage
      (route) => false, // ล้าง Stack ของ Route ทั้งหมด
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // ผู้ใช้ปัจจุบัน
    final isAdmin = user?.email == 'admintoilet0012@gmail.com'; // ตรวจสอบว่าเป็น Admin
    final isGuest = user == null; // ตรวจสอบว่าเป็น Guest

    return Scaffold(
      body: Stack(
        children: [
          // ── แผนที่ ──
          GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: _defaultLocation, // ตำแหน่งเริ่มต้นของกล้อง
            mapToolbarEnabled: false, // ปิด Toolbar บนแผนที่
            onMapCreated: (GoogleMapController controller) { // เมื่อแผนที่ถูกสร้างเสร็จ
              _controller.complete(controller); // ส่ง Controller ให้ Completer
            },
            zoomControlsEnabled: true, // แสดงปุ่มซูมเข้า-ออก (ค่าเริ่มต้นคือ true อยู่แล้ว)
            myLocationEnabled: true, // เปิดใช้งาน My Location
            myLocationButtonEnabled: false, // ปิดปุ่ม My Location (เราสร้างเอง)
            markers: _markers, // Marker ที่จะแสดงบนแผนที่
            onCameraMove: (CameraPosition position) { // เมื่อกล้องบนแผนที่เคลื่อนที่
              _currentMapCenter = position.target; // อัปเดตพิกัดกลางแผนที่
            },
          ),

          // ── เป้าเล็ง ──
          if (_isPinningMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Column( // UI เป้าเล็ง
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container( // วงกลมรอบไอคอน
                      padding: const EdgeInsets.all(6), // ระยะห่างภายใน
                      decoration: BoxDecoration(
                        color: _pink.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_rounded, size: 50, color: _deepPink),
                    ),
                    const SizedBox(height: 8),
                    Container( // ข้อความ "เล็งตรงนี้เลย!"
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // ระยะห่างภายใน
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: _pink.withOpacity(0.2), blurRadius: 10)],
                      ),
                      child: const Text("เล็งตรงนี้เลย!",
                          style: TextStyle(color: _deepPink, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),

          // ── AppBar แบบ custom ──
          if (!_isPinningMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration( // ตกแต่ง AppBar
                  gradient: LinearGradient(
                    colors: [_pink, _deepPink],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight, // ไล่สีจากซ้ายไปขวา
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [ // ไอคอน, ชื่อแอป, ชื่อผู้ใช้, ปุ่ม Admin, ปุ่ม Logout
                        const Icon(Icons.wc_rounded, color: Colors.white, size: 28), // ไอคอนห้องน้ำ
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Hong Nam",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              Text( // แสดงชื่อผู้ใช้ หรือ Guest
                                isGuest
                                    ? "Guest"
                                    : (user?.displayName ?? "Anonymous"),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ), // Expanded เพื่อให้ Column กินพื้นที่ที่เหลือ
                        if (isAdmin) // ถ้าเป็น Admin
                          IconButton( // ปุ่มไปหน้า Admin
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminPage()),
                            ),
                            icon: const Icon(Icons.admin_panel_settings_rounded,
                                color: Colors.amber), // ไอคอน Admin
                          ),
                        IconButton( // ปุ่ม Logout
                          onPressed: () => logout(context),
                          icon: const Icon(Icons.logout_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── ช่องค้นหา ──
          if (!_isPinningMode)
            Positioned(
              top: 90 + MediaQuery.of(context).padding.top,
              left: 15,
              right: 15,
              child: Container(
                height: 50, // ความสูงของช่องค้นหา
                decoration: BoxDecoration( // ตกแต่งช่องค้นหา
                  color: Colors.white, // สีพื้นหลัง
                  borderRadius: BorderRadius.circular(25), // ขอบโค้ง
                  boxShadow: [ // เงา
                    BoxShadow(
                      color: _pink.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController, // Controller
                  textInputAction: TextInputAction.search, // ปุ่ม Enter บนคีย์บอร์ดเป็น Search
                  onSubmitted: (_) => _searchPlace(), // เมื่อกด Search
                  decoration: InputDecoration( // ตกแต่ง TextField
                    hintText: "ค้นหาสถานที่...", // Placeholder
                    hintStyle: TextStyle(color: Colors.pink[200]), // สไตล์ Placeholder
                    border: InputBorder.none, // ไม่มีเส้นขอบ
                    contentPadding:
                        const EdgeInsets.only(left: 20, top: 15), // ระยะห่าง Content
                    suffixIcon: IconButton( // ไอคอนค้นหา
                      icon: const Icon(Icons.search_rounded, color: _pink),
                      onPressed: () {
                        _searchPlace();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                ),
              ),
            ),

          // ── ปุ่ม My Location ──
          if (!_isPinningMode)
            Positioned(
              bottom: 110,
              right: 10,
              child: GestureDetector(
                onTap: _determinePosition,
                child: Container( // ปุ่ม My Location
                  width: 44, // ความกว้าง
                  height: 44, // ความสูง
                  decoration: BoxDecoration( // ตกแต่ง
                    color: Colors.white, // สีพื้นหลัง
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _pink.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.my_location_rounded,
                      color: _pink, size: 22),
                ),
              ),
            ),

          // ── แถบปุ่มล่าง ──
          Positioned(
            bottom: 30,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_isPinningMode) ...[
                  _buildBottomActionBtn( // ปุ่มยกเลิกในโหมดปักหมุด
                    label: "ยกเลิก", // ข้อความ
                    icon: Icons.close_rounded, // ไอคอน
                    color: Colors.grey[600]!, // สีข้อความ/ไอคอน
                    bgColor: Colors.white, // สีพื้นหลัง
                    onTap: () => setState(() => _isPinningMode = false), // เมื่อกด ให้ยกเลิกโหมดปักหมุด
                  ),
                  _buildBottomActionBtn( // ปุ่ม "เล็งตรงนี้!" ในโหมดปักหมุด
                    label: "เล็งตรงนี้!", // ข้อความ
                    icon: Icons.check_rounded, // ไอคอน
                    color: Colors.white, // สีข้อความ/ไอคอน
                    bgColor: _pink, // สีพื้นหลัง
                    onTap: () => _showAddToiletDialog(), // เมื่อกด ให้แสดง Dialog เพิ่มห้องน้ำ
                    isMain: true, // เป็นปุ่มหลัก
                  ),
                ] else ...[
                  _buildMenuButton( // ปุ่มเปลี่ยนประเภทแผนที่
                      icon: Icons.layers_rounded, onPressed: _toggleMapType), // เมื่อกด ให้สลับประเภทแผนที่
                  if (!isGuest) // ถ้าไม่ใช่ Guest
                    _buildMenuButton( // ปุ่มปักหมุดห้องน้ำใหม่
                      icon: Icons.add_location_alt_rounded, // ไอคอน
                      isBig: true, // ปุ่มขนาดใหญ่
                      onPressed: () => setState(() => _isPinningMode = true), // เมื่อกด ให้เข้าสู่โหมดปักหมุด
                    ),
                  if (!isGuest)
                    _buildMenuButton(
                        icon: Icons.person_rounded,
                        onPressed: _showProfileDialog),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    bool isMain = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric( // ระยะห่างภายใน
            horizontal: isMain ? 28 : 20, vertical: 14), // ถ้าเป็นปุ่มหลักจะกว้างกว่า
        decoration: BoxDecoration( // ตกแต่ง
          color: bgColor, // สีพื้นหลัง
          borderRadius: BorderRadius.circular(22), // ขอบโค้ง
          boxShadow: [
            BoxShadow(
              color: (isMain ? _pink : Colors.grey).withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row( // ไอคอนและข้อความ
          mainAxisSize: MainAxisSize.min, // ให้ Row ใช้พื้นที่เท่าที่จำเป็น
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}