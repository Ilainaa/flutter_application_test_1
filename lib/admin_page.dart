import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  // ── สีธีมหลัก ──
  static const Color _pink = Color(0xFFE91E8C);
  static const Color _lightPink = Color(0xFFFCE4EC);
  static const Color _softPink = Color(0xFFF8BBD0);
  static const Color _deepPink = Color(0xFFC2185B);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F5),
        appBar: AppBar(
          title: const Text(
            "🛡️ ระบบหลังบ้าน",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_pink, _deepPink],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            splashBorderRadius: BorderRadius.circular(12),
            tabs: const [
              Tab(
                icon: Icon(Icons.map_rounded),
                text: "จัดการหมุด",
              ),
              Tab(
                icon: Icon(Icons.flag_rounded),
                text: "รายงานปัญหา",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildToiletManager(),
            _buildReportManager(),
          ],
        ),
      ),
    );
  }

  // ── แท็บ 1: จัดการหมุด ──
  Widget _buildToiletManager() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('toilets').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: _pink));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.map_rounded,
            message: "ไม่มีข้อมูลหมุดในระบบเลยค่ะ",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            String status = data['status'] ?? 'pending';
            bool isBroken = data['isBroken'] ?? false;

            Color cardColor;
            String statusLabel;
            Color statusColor;
            IconData statusIcon;

            if (status == 'pending') {
              cardColor = const Color(0xFFFFF9C4);
              statusLabel = 'รออนุมัติ';
              statusColor = const Color(0xFFF9A825);
              statusIcon = Icons.hourglass_bottom_rounded;
            } else if (isBroken) {
              cardColor = const Color(0xFFFFEBEE);
              statusLabel = 'ชำรุด';
              statusColor = Colors.red;
              statusIcon = Icons.warning_rounded;
            } else {
              cardColor = const Color(0xFFE8F5E9);
              statusLabel = 'ปกติ';
              statusColor = Colors.green;
              statusIcon = Icons.check_circle_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // รูปภาพ
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: data['imageUrl'] != null
                          ? Image.network(
                              data['imageUrl'],
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: _lightPink,
                              child: const Icon(Icons.image_not_supported_rounded,
                                  color: _pink),
                            ),
                    ),
                    const SizedBox(width: 14),

                    // ข้อความ
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['description'] != "" && data['description'] != null
                                ? data['description']
                                : 'ไม่มีคำอธิบาย',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF3A003A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ผู้ปัก: ${data['authorName'] ?? 'ไม่ทราบ'}",
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ปุ่มดำเนินการ
                    Column(
                      children: [
                        if (status == 'pending')
                          _actionBtn(
                            icon: Icons.check_rounded,
                            color: Colors.green,
                            bgColor: const Color(0xFFE8F5E9),
                            onTap: () async => await FirebaseFirestore.instance
                                .collection('toilets')
                                .doc(doc.id)
                                .update({'status': 'approved', 'isBroken': false}),
                          ),
                        if (status == 'approved')
                          _actionBtn(
                            icon: isBroken ? Icons.build_rounded : Icons.warning_rounded,
                            color: isBroken ? Colors.blue : Colors.orange,
                            bgColor: isBroken
                                ? const Color(0xFFE3F2FD)
                                : const Color(0xFFFFF3E0),
                            onTap: () async => await FirebaseFirestore.instance
                                .collection('toilets')
                                .doc(doc.id)
                                .update({'isBroken': !isBroken}),
                          ),
                        const SizedBox(height: 6),
                        _actionBtn(
                          icon: Icons.delete_rounded,
                          color: _deepPink,
                          bgColor: _lightPink,
                          onTap: () => FirebaseFirestore.instance
                              .collection('toilets')
                              .doc(doc.id)
                              .delete(),
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

  // ── แท็บ 2: รายงานปัญหา ──
  Widget _buildReportManager() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _pink));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.sentiment_very_satisfied_rounded,
            message: "ไม่มีการรายงานปัญหาเข้ามาค่ะ\nสบายใจได้เลย! ✨",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _softPink, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _lightPink.withOpacity(0.6),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _lightPink,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.flag_rounded, color: _deepPink),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['reason'] ?? 'ไม่ระบุสาเหตุ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF4A0020),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person_rounded,
                                  size: 13, color: Colors.pink[300]),
                              const SizedBox(width: 4),
                              Text(
                                data['reporterName'] ?? 'ไม่ทราบ',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.pin_drop_rounded,
                                  size: 13, color: Colors.pink[300]),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  "ID: ${data['toiletId'] ?? '-'}",
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _actionBtn(
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      bgColor: const Color(0xFFE8F5E9),
                      onTap: () => FirebaseFirestore.instance
                          .collection('reports')
                          .doc(doc.id)
                          .delete(),
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

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _lightPink,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, color: _pink, size: 44),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.pink[300],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}