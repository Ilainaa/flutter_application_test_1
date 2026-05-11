import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'admin_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_page.dart';
import 'tutorial_dialog.dart';

// ── ตัวแปรเก็บหมวดหมู่ ──
String _selectedFilter = 'ทั้งหมด';
final List<String> _categories = [
  'ทั้งหมด',
  'ห้องน้ำ',
  'ถังขยะ',
  'ตู้กดน้ำ',
  'ร้านซักผ้า',
];

// ── สีธีมหลัก (ใช้งานทั้งไฟล์) ──
const Color _pink = Color(0xFFE91E8C);
const Color _lightPink = Color(0xFFFCE4EC);
const Color _softPink = Color(0xFFF8BBD0);
const Color _deepPink = Color(0xFFC2185B);

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

  String _myDescription = "";
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isPinningMode = false;
  LatLng _currentMapCenter = const LatLng(13.764953, 100.538316);

  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(13.764953, 100.538316),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _listenToApprovedPoints(); // 🚨 แก้ชื่อฟังก์ชันให้สอดคล้องกับ points

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showTutorialIfNeeded(context);
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 17,
        ),
      ),
    );
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType =
          _currentMapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
  }

  Future<void> _searchPlace() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(locations.first.latitude, locations.first.longitude),
              zoom: 16,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar("หาสถานที่ไม่เจอ ลองพิมพ์ให้ชัดเจนขึ้นนะคะ", isError: true);
    }
  }

  Future<void> _navigateToPoint(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar("ไม่สามารถเปิดระบบนำทางได้ครับ", isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false, bool isSuccess = false}) {
    Color bg = isError ? _deepPink : (isSuccess ? Colors.green : _pink);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  // 🚨 เปลี่ยนคอลเลกชันจาก toilets เป็น points
  void _listenToApprovedPoints() {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email == 'admintoilet0012@gmail.com';

    Query query = FirebaseFirestore.instance.collection('points'); // 🚨 จุดแก้

    if (!isAdmin) {
      query = query.where('status', isEqualTo: 'approved');
    }

    query.snapshots().listen((snapshot) {
      Set<Marker> newMarkers = {};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String category = data['category'] ?? 'ห้องน้ำ';

        // ระบบกรองหมวดหมู่
        if (_selectedFilter != 'ทั้งหมด' && category != _selectedFilter) {
          continue;
        }

        LatLng position = LatLng(data['latitude'], data['longitude']);
        String status = data['status'] ?? 'pending';
        bool isFree = data['isFree'] ?? true;
        bool isBroken = data['isBroken'] ?? false;

        String titleText;
        double pinColor;

        if (status == 'pending') {
          titleText = '⏳ รอตรวจสอบ';
          pinColor = BitmapDescriptor.hueCyan;
        } else if (isBroken) {
          titleText = '❌ ชำรุด / ปิดซ่อมแซม';
          pinColor = BitmapDescriptor.hueRed;
        } else if (isFree) {
          titleText = '🆓 ใช้งานฟรี';
          pinColor = BitmapDescriptor.hueGreen;
        } else {
          titleText = '💰 มีค่าบริการ';
          pinColor = BitmapDescriptor.hueOrange;
        }

        newMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: position,
            onTap: () => _showPointDetails(doc.id, data), // ส่งไปหน้า Detail
            icon: BitmapDescriptor.defaultMarkerWithHue(pinColor),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(newMarkers);
        });
      }
    });
  }

  // 🚨 ฟังก์ชันแสดงรายละเอียดหมุด (ปรับให้รองรับหลายหมวดหมู่)
  void _showPointDetails(String docId, Map<String, dynamic> data) {
    String category = data['category'] ?? 'ห้องน้ำ';
    bool isFree = data['isFree'] ?? true;
    bool isBroken = data['isBroken'] ?? false;
    
    // ดึงข้อมูลหมวดหมู่ย่อยแบบปลอดภัย
    Map<String, dynamic> getMap(String key) {
      return (data[key] != null && data[key] is Map) ? Map<String, dynamic>.from(data[key]) : {};
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final String myUid = currentUser?.uid ?? 'anonymous';
    final bool isGuest = FirebaseAuth.instance.currentUser == null;
    Map<String, dynamic> ratings = getMap('ratings');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44, height: 5,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: _softPink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    if (data['imageUrl'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          data['imageUrl'],
                          width: double.infinity, height: 200, fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isBroken ? const Color(0xFFFFEBEE) : (category == 'ถังขยะ' ? _lightPink : (isFree ? const Color(0xFFE8F5E9) : _lightPink)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isBroken ? '❌ ปิดซ่อมแซม' : (category == 'ถังขยะ' ? '🗑️ จุดทิ้งขยะ' : (isFree ? '🆓 บริการฟรี' : '💰 มีค่าบริการ')),
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: isBroken ? Colors.red[700] : (category == 'ถังขยะ' ? _deepPink : (isFree ? Colors.green[700] : _deepPink)),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 26),
                            const SizedBox(width: 4),
                            Text(
                              "${avgRating.toStringAsFixed(1)} ($totalVotes)",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── ข้อมูลพื้นฐาน (ตามหมวดหมู่) ──
                    if (category == 'ห้องน้ำ') ...[
                      _infoRow(Icons.wc_rounded, _pink, "สไตล์: ${data['toiletStyle'] ?? 'ไม่ระบุ'}"),
                      if (!isFree && data['paymentMethod'] != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(Icons.payment_rounded, Colors.green, "รับชำระ: ${data['paymentMethod']}"),
                      ],
                    ] else if (category == 'ถังขยะ') ...[
                      _infoRow(Icons.place_rounded, _pink, "ตำแหน่ง: ${data['trashLocation'] ?? 'ไม่ระบุ'}"),
                    ] else if (category == 'ร้านซักผ้า') ...[
                      _infoRow(Icons.air_rounded, _pink, "ระบายอากาศ: ${data['coolingSystem'] ?? 'ไม่ระบุ'}"),
                    ],
                    const SizedBox(height: 16),

                    // ── สิ่งอำนวยความสะดวก ──
                    const Text(
                      "✨ สิ่งอำนวยความสะดวก / บริการ",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _deepPink),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: [
                        if (category == 'ห้องน้ำ') ...[
                          if (getMap('amenities')['hasTissue'] == true) _amenityChip("🧻 ทิชชู่"),
                          if (getMap('amenities')['hasBidet'] == true) _amenityChip("🚿 สายชำระ"),
                          if (getMap('amenities')['hasSoap'] == true) _amenityChip("🧼 สบู่"),
                        ] else if (category == 'ถังขยะ') ...[
                          ...getMap('trashTypes').entries.where((e) => e.value == true).map((e) => _amenityChip("🗑️ ${e.key}")),
                        ] else if (category == 'ตู้กดน้ำ') ...[
                          ...getMap('waterTypes').entries.where((e) => e.value == true).map((e) => _amenityChip("💧 ${e.key}")),
                        ] else if (category == 'ร้านซักผ้า') ...[
                          ...getMap('laundryAmenities').entries.where((e) => e.value == true).map((e) => _amenityChip("👕 ${e.key}")),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── รายละเอียดเพิ่มเติม ──
                    const Text(
                      "📝 รายละเอียดเพิ่มเติม",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _deepPink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['description'] != "" && data['description'] != null
                          ? data['description']
                          : 'ไม่ได้ระบุรายละเอียดเพิ่มเติมไว้ค่ะ',
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: _lightPink, thickness: 1.5),
                    const SizedBox(height: 12),

                    // ── ให้คะแนน ──
                    if (!isGuest) ...[
                      const Text(
                        "⭐ ให้คะแนนจุดบริการนี้",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _deepPink),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          int starValue = index + 1;
                          return GestureDetector(
                            onTap: () async {
                              setSheetState(() => ratings[myUid] = starValue);
                              // 🚨 อัปเดตคะแนนลงคอลเลกชัน points
                              await FirebaseFirestore.instance
                                  .collection('points')
                                  .doc(docId)
                                  .update({'ratings.$myUid': starValue});
                            },
                            child: Icon(
                              starValue <= myCurrentRating ? Icons.star_rounded : Icons.star_border_rounded,
                              color: Colors.amber, size: 38,
                            ),
                          );
                        }),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _lightPink, borderRadius: BorderRadius.circular(14)),
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

                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 24),
                        label: const Text("นำทางไปที่นี่", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToPoint(data['latitude'], data['longitude']);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.flag_rounded, color: _deepPink),
                        label: const Text(
                          "รายงานปัญหา / แจ้งหมุดไม่ถูกต้อง",
                          style: TextStyle(color: _deepPink, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _softPink, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: _lightPink.withOpacity(0.3),
                        ),
                        onPressed: () {
                          if (isGuest) {
                            showDialog(
                              context: context,
                              builder: (ctx) => _buildPinkDialog(
                                ctx, title: "🔒 แจ้งเตือน",
                                content: "ฟังก์ชันนี้สงวนไว้สำหรับสมาชิกค่ะ\nกรุณาเข้าสู่ระบบเพื่อร่วมรายงานปัญหา",
                                onConfirm: () => Navigator.pop(ctx), confirmLabel: "ตกลง",
                              ),
                            );
                          } else {
                            _showReportDialog(docId);
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

  Widget _infoRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget _amenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: _lightPink, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(fontSize: 13, color: _deepPink)),
    );
  }

  Widget _buildPinkDialog(
    BuildContext ctx, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
    required String confirmLabel,
    VoidCallback? onCancel,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _deepPink, fontSize: 18)),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: Text(content, style: TextStyle(color: Colors.grey[700], height: 1.5)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[500])),
          ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _pink, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  void _showReportDialog(String pointId) {
    TextEditingController reportController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _lightPink, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.flag_rounded, color: _deepPink, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text("รายงานปัญหา", style: TextStyle(color: _deepPink, fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("พบปัญหาอะไรเกี่ยวกับจุดนี้คะ?", style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reportController, maxLines: 3,
                    style: const TextStyle(color: Color(0xFF4A0020)),
                    decoration: InputDecoration(
                      hintText: "เช่น ชำรุด, สกปรกมาก, ปิดถาวร...",
                      hintStyle: TextStyle(color: Colors.grey[400]), filled: true,
                      fillColor: _lightPink.withOpacity(0.4),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _softPink)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _pink, width: 2)),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                if (!isSubmitting)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[500])),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (reportController.text.trim().isEmpty) {
                            _showSnackBar("กรุณากรอกรายละเอียดปัญหาก่อนส่งค่ะ", isError: true);
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final user = FirebaseAuth.instance.currentUser;
                          try {
                            await FirebaseFirestore.instance.collection('reports').add({
                              'toiletId': pointId, // เก็บ ID ของหมุด (ใช้คีย์เดิมให้ Admin อ่านได้)
                              'reason': reportController.text.trim(),
                              'reporterId': user?.uid,
                              'reporterName': user?.displayName ?? 'Anonymous Hero',
                              'timestamp': FieldValue.serverTimestamp(),
                              'status': 'pending',
                            });

                            // 🚨 อัปเดตคอลเลกชัน points
                            await FirebaseFirestore.instance.collection('points').doc(pointId).update({
                              'isBroken': true,
                            });
                            Navigator.pop(context);
                            _showSnackBar("✅ ขอบคุณที่ช่วยรายงานค่ะ แอดมินจะรีบตรวจสอบ!", isSuccess: true);
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar("❌ เกิดข้อผิดพลาด: $e", isError: true);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("ส่งรายงาน", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? "";
    _descController.text = _myDescription;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _lightPink, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_rounded, color: _pink, size: 20),
              ),
              const SizedBox(width: 10),
              const Text("ตั้งค่าโปรไฟล์", style: TextStyle(color: _deepPink, fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField(controller: _nameController, label: "ชื่อของคุณ", icon: Icons.person_rounded),
              const SizedBox(height: 14),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[500])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  await user?.updateDisplayName(_nameController.text);
                  await user?.reload();
                }
                setState(() => _myDescription = _descController.text);
                Navigator.pop(context);
                _showSnackBar("✅ บันทึกข้อมูลโปรไฟล์เรียบร้อยแล้ว!", isSuccess: true);
              },
              child: const Text("บันทึก", style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF4A0020)),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: Colors.pink[300]),
        prefixIcon: Icon(icon, color: _pink), filled: true, fillColor: _lightPink.withOpacity(0.35),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _softPink)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _pink, width: 2)),
      ),
    );
  }

  // 🚨 ฟอร์มเพิ่มหมุดแบบ Dynamic แยกตามหมวดหมู่
  void _showAddToiletDialog() {
    TextEditingController detailController = TextEditingController();
    String _newPinCategory = 'ห้องน้ำ';
    int rating = 5;
    File? selectedImage;
    bool isUploading = false;

    // ตัวแปรสำหรับ "ห้องน้ำ"
    bool isFree = true;
    String paymentMethod = 'เงินสด';
    String toiletStyle = 'ชักโครก';
    bool hasTissue = false; bool hasBidet = false; bool hasSoap = false;

    // ตัวแปรสำหรับ "ถังขยะ"
    Map<String, bool> trashTypes = {'ขยะเปียก': false, 'ขยะทั่วไป': false, 'ขยะรีไซเคิล': false, 'ขยะอันตราย': false};
    String trashLocation = 'ในอาคาร';

    // ตัวแปรสำหรับ "ตู้กดน้ำ"
    bool isWaterFree = false;
    Map<String, bool> waterTypes = {'น้ำเย็น': false, 'น้ำอุณหภูมิห้อง': false, 'น้ำร้อน': false};

    // ตัวแปรสำหรับ "ร้านซักผ้า"
    Map<String, bool> laundryAmenities = {
      'เครื่องซักผ้า': true, 'เครื่องอบผ้า': false, 'ตู้กดน้ำยา': false, 
      'เครื่องแลกเหรียญ': false, 'อ่างล้างมือ': false, 'ที่นั่งรอ': false
    };
    String coolingSystem = 'พัดลม';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _lightPink, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_location_alt_rounded, color: _pink, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text("📍 เพิ่มจุดสังเกต", style: TextStyle(fontWeight: FontWeight.w800, color: _deepPink, fontSize: 17)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 14),

                      // Dropdown เลือกหมวดหมู่
                      DropdownButtonFormField<String>(
                        value: _newPinCategory,
                        decoration: InputDecoration(
                          labelText: 'ประเภทจุดสังเกต',
                          prefixIcon: const Icon(Icons.category_rounded, color: _pink),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['ห้องน้ำ', 'ถังขยะ', 'ตู้กดน้ำ', 'ร้านซักผ้า'].map((String val) {
                          return DropdownMenuItem(value: val, child: Text(val));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => _newPinCategory = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // 🚨 ส่วนฟอร์มที่จะเปลี่ยนไปตามหมวดหมู่
                      if (_newPinCategory == 'ห้องน้ำ') ...[
                        _sectionLabel("ประเภทห้องน้ำ"),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _choiceBtn("ฟรี", isFree == true, () => setDialogState(() => isFree = true)),
                            const SizedBox(width: 10),
                            _choiceBtn("เสียเงิน", isFree == false, () => setDialogState(() => isFree = false)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child: isFree ? const SizedBox.shrink() : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("การชำระเงิน"),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8, runSpacing: 6,
                                children: ['เงินสด', 'สแกนจ่าย', 'ทั้งสองอย่าง'].map(
                                  (m) => _choiceBtn(m, paymentMethod == m, () => setDialogState(() => paymentMethod = m))
                                ).toList(),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                        _sectionLabel("สไตล์ห้องน้ำ"),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['ชักโครก', 'นั่งยอง'].map(
                            (s) => _choiceBtn(s, toiletStyle == s, () => setDialogState(() => toiletStyle = s))
                          ).toList(),
                        ),
                        const SizedBox(height: 10),
                        _sectionLabel("สิ่งอำนวยความสะดวก"),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: [
                            _filterChip("🧻 ทิชชู่", hasTissue, (v) => setDialogState(() => hasTissue = v)),
                            _filterChip("🚿 สายชำระ", hasBidet, (v) => setDialogState(() => hasBidet = v)),
                            _filterChip("🧼 สบู่", hasSoap, (v) => setDialogState(() => hasSoap = v)),
                          ],
                        ),
                      ] 
                      else if (_newPinCategory == 'ถังขยะ') ...[
                        _sectionLabel("ประเภทขยะที่รองรับ"),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: trashTypes.keys.map((key) => _filterChip(key, trashTypes[key]!, (v) => setDialogState(() => trashTypes[key] = v))).toList(),
                        ),
                        const SizedBox(height: 10),
                        _sectionLabel("ตำแหน่งที่ตั้ง"),
                        const SizedBox(height: 8),
                        Row(
                          children: ['ในอาคาร', 'กลางแจ้ง'].map(
                            (l) => Padding(padding: const EdgeInsets.only(right: 8), child: _choiceBtn(l, trashLocation == l, () => setDialogState(() => trashLocation = l)))
                          ).toList(),
                        ),
                      ]
                      else if (_newPinCategory == 'ตู้กดน้ำ') ...[
                        _sectionLabel("ค่าบริการ"),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _choiceBtn("ฟรี", isWaterFree == true, () => setDialogState(() => isWaterFree = true)),
                            const SizedBox(width: 10),
                            _choiceBtn("เสียเงิน", isWaterFree == false, () => setDialogState(() => isWaterFree = false)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _sectionLabel("ประเภทน้ำที่มีให้บริการ"),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: waterTypes.keys.map((key) => _filterChip(key, waterTypes[key]!, (v) => setDialogState(() => waterTypes[key] = v))).toList(),
                        ),
                      ]
                      else if (_newPinCategory == 'ร้านซักผ้า') ...[
                        _sectionLabel("ระบบระบายอากาศ"),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: ['แอร์', 'พัดลม', 'ธรรมชาติ'].map(
                            (c) => _choiceBtn(c, coolingSystem == c, () => setDialogState(() => coolingSystem = c))
                          ).toList(),
                        ),
                        const SizedBox(height: 10),
                        _sectionLabel("สิ่งอำนวยความสะดวกในร้าน"),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: laundryAmenities.keys.map((key) => _filterChip(key, laundryAmenities[key]!, (v) => setDialogState(() => laundryAmenities[key] = v))).toList(),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // ส่วนที่ใช้ร่วมกันทุกหมวดหมู่ (รายละเอียด, รูปภาพ, ให้คะแนน)
                      _sectionLabel("คะแนนความพึงพอใจ"),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (i) {
                          return GestureDetector(
                            onTap: () => setDialogState(() => rating = i + 1),
                            child: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 34),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),

                      _sectionLabel("รายละเอียดเพิ่มเติม"),
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailController, maxLines: 2,
                        style: const TextStyle(color: Color(0xFF4A0020)),
                        decoration: InputDecoration(
                          hintText: "เช่น อยู่ชั้น 1 ติดบันไดเลื่อน",
                          hintStyle: TextStyle(color: Colors.grey[400]), filled: true, fillColor: _lightPink.withOpacity(0.35),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _softPink)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _pink, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      _sectionLabel("รูปภาพสถานที่"),
                      const SizedBox(height: 8),
                      Center(
                        child: selectedImage != null
                            ? Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_rounded, color: _deepPink, size: 28),
                                    onPressed: () => setDialogState(() => selectedImage = null),
                                  ),
                                ],
                              )
                            : GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                                  if (pickedFile != null) setDialogState(() => selectedImage = File(pickedFile.path));
                                },
                                child: Container(
                                  width: double.infinity, height: 100,
                                  decoration: BoxDecoration(
                                    color: _lightPink.withOpacity(0.5), borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _softPink, width: 1.5),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.photo_library_rounded, color: _pink, size: 32),
                                      SizedBox(height: 6),
                                      Text("เลือกรูปจากแกลเลอรี่", style: TextStyle(color: _deepPink, fontWeight: FontWeight.w600)),
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
                if (!isUploading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("ยกเลิก", style: TextStyle(color: Colors.grey[500])),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isUploading
                      ? null
                      : () async {
                          setDialogState(() => isUploading = true);
                          String? imageUrl;
                          final user = FirebaseAuth.instance.currentUser;

                          try {
                            if (selectedImage != null) {
                              // 🚨 เปลี่ยนโฟลเดอร์ใน Storage เป็น points ด้วย
                              String fileName = 'points/${DateTime.now().millisecondsSinceEpoch}.jpg';
                              Reference ref = FirebaseStorage.instance.ref().child(fileName);
                              UploadTask uploadTask = ref.putFile(selectedImage!);
                              TaskSnapshot snap = await uploadTask;
                              imageUrl = await snap.ref.getDownloadURL();
                            }

                            // 🚨 สร้างก้อนข้อมูลที่แยกตามหมวดหมู่
                            Map<String, dynamic> dataToSave = {
                              'category': _newPinCategory,
                              'latitude': _currentMapCenter.latitude,
                              'longitude': _currentMapCenter.longitude,
                              'description': detailController.text,
                              'imageUrl': imageUrl,
                              'status': 'pending',
                              'authorName': user?.displayName ?? 'Anonymous Hero',
                              'authorId': user?.uid,
                              'timestamp': FieldValue.serverTimestamp(),
                              'ratings': { user?.uid ?? 'anonymous': rating },
                            };

                            // แปะข้อมูลเพิ่มเติมตาม category
                            if (_newPinCategory == 'ห้องน้ำ') {
                              dataToSave.addAll({
                                'isFree': isFree,
                                'paymentMethod': isFree ? null : paymentMethod,
                                'toiletStyle': toiletStyle,
                                'amenities': {'hasTissue': hasTissue, 'hasBidet': hasBidet, 'hasSoap': hasSoap},
                              });
                            } else if (_newPinCategory == 'ถังขยะ') {
                              dataToSave.addAll({
                                'trashTypes': trashTypes,
                                'trashLocation': trashLocation,
                              });
                            } else if (_newPinCategory == 'ตู้กดน้ำ') {
                              dataToSave.addAll({
                                'isFree': isWaterFree,
                                'waterTypes': waterTypes,
                              });
                            } else if (_newPinCategory == 'ร้านซักผ้า') {
                              dataToSave.addAll({
                                'laundryAmenities': laundryAmenities,
                                'coolingSystem': coolingSystem,
                              });
                            }

                            // 🚨 บันทึกลง collection 'points'
                            await FirebaseFirestore.instance.collection('points').add(dataToSave);

                            Navigator.pop(context);
                            setState(() => _isPinningMode = false);
                            _showSnackBar("✅ ส่งข้อมูลให้แอดมินตรวจสอบแล้วค่ะ!", isSuccess: true);
                          } catch (e) {
                            setDialogState(() => isUploading = false);
                            _showSnackBar("❌ เกิดข้อผิดพลาด: $e", isError: true);
                          }
                        },
                  child: isUploading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("ยืนยันพิกัด", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _deepPink));
  }

  Widget _choiceBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _pink : _lightPink.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected ? [BoxShadow(color: _pink.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : _deepPink, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, Function(bool) onSelected) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _pink : _lightPink.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected ? [BoxShadow(color: _pink.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.check_rounded, color: Colors.white, size: 14)),
            Text(label, style: TextStyle(color: selected ? Colors.white : _deepPink, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({required IconData icon, required VoidCallback onPressed, bool isBig = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _pink.withOpacity(0.2), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Icon(icon, size: isBig ? 30 : 26, color: _pink),
      ),
    );
  }

  void logout(BuildContext context) async {
    final isGuest = FirebaseAuth.instance.currentUser == null;
    if (!isGuest) {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    }
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email == 'admintoilet0012@gmail.com';
    final isGuest = user == null;

    return Scaffold(
      body: Stack(
        children: [
          // ── แผนที่ ──
          GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: _defaultLocation,
            mapToolbarEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            zoomControlsEnabled: true,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onCameraMove: (CameraPosition position) {
              _currentMapCenter = position.target;
            },
          ),

          // ── เป้าเล็ง ──
          if (_isPinningMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _pink.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.location_on_rounded, size: 50, color: _deepPink),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: _pink.withOpacity(0.2), blurRadius: 10)],
                      ),
                      child: const Text("เล็งตรงนี้เลย!", style: TextStyle(color: _deepPink, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),

          // ── AppBar แบบ custom ──
          if (!_isPinningMode)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_pink, _deepPink], begin: Alignment.centerLeft, end: Alignment.centerRight),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white, size: 28), // เปลี่ยนเป็นไอคอนโลเคชั่นแทนห้องน้ำ
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Hero Map", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              Text(isGuest ? "Guest" : (user?.displayName ?? "Anonymous"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (isAdmin)
                          IconButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage())),
                            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
                          ),
                        IconButton(onPressed: () => logout(context), icon: const Icon(Icons.logout_rounded, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Widget เมนูตัวเลือก (Dropdown) ──
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.95),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _pink.withOpacity(0.3), width: 1.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      icon: const Icon(Icons.filter_list_rounded, color: _pink),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Kanit'),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(value: category, child: Text(category));
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedFilter = newValue);
                          _listenToApprovedPoints(); // โหลดใหม่เวลากรองเปลี่ยน
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── ช่องค้นหา ──
          if (!_isPinningMode)
            Positioned(
              top: 90 + MediaQuery.of(context).padding.top, left: 15, right: 15,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: _pink.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: _searchController, textInputAction: TextInputAction.search, onSubmitted: (_) => _searchPlace(),
                  decoration: InputDecoration(
                    hintText: "ค้นหาสถานที่...", hintStyle: TextStyle(color: Colors.pink[200]), border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(left: 20, top: 15),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded, color: _pink),
                      onPressed: () { _searchPlace(); FocusScope.of(context).unfocus(); },
                    ),
                  ),
                ),
              ),
            ),

          // ── ปุ่ม My Location ──
          if (!_isPinningMode)
            Positioned(
              bottom: 110, right: 10,
              child: GestureDetector(
                onTap: _determinePosition,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _pink.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.my_location_rounded, color: _pink, size: 22),
                ),
              ),
            ),

          // ── แถบปุ่มล่าง ──
          Positioned(
            bottom: 30, left: 40, right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_isPinningMode) ...[
                  _buildBottomActionBtn(
                    label: "ยกเลิก", icon: Icons.close_rounded,
                    color: Colors.grey[600]!, bgColor: Colors.white,
                    onTap: () => setState(() => _isPinningMode = false),
                  ),
                  _buildBottomActionBtn(
                    label: "เล็งตรงนี้!", icon: Icons.check_rounded,
                    color: Colors.white, bgColor: _pink,
                    onTap: () => _showAddToiletDialog(), isMain: true,
                  ),
                ] else ...[
                  _buildMenuButton(icon: Icons.layers_rounded, onPressed: _toggleMapType),
                  if (!isGuest)
                    _buildMenuButton(icon: Icons.add_location_alt_rounded, isBig: true, onPressed: () => setState(() => _isPinningMode = true)),
                  if (!isGuest)
                    _buildMenuButton(icon: Icons.person_rounded, onPressed: _showProfileDialog),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBtn({required String label, required IconData icon, required Color color, required Color bgColor, required VoidCallback onTap, bool isMain = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMain ? 28 : 20, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: (isMain ? _pink : Colors.grey).withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}