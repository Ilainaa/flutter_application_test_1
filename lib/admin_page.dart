import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ใช้ DefaultTabController เพื่อสร้างระบบแท็บเลื่อนซ้ายขวา
    return DefaultTabController(
      length: 2, // ระบุว่าเรามี 2 แท็บ
      child: Scaffold(
        appBar: AppBar(
          title: Text("ระบบหลังบ้าน (Admin)", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red[900],
          foregroundColor: Colors.white,
          // --- สร้างแถบเมนู Tabs ด้านล่างของ AppBar ---
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            indicatorWeight: 4,
            tabs: [
              Tab(icon: Icon(Icons.map), text: "จัดการหมุด"),
              Tab(icon: Icon(Icons.report_problem), text: "รายงานปัญหา"),
            ],
          ),
        ),
        // --- ส่วนเนื้อหาของแต่ละแท็บ ---
        body: TabBarView(
          children: [
            // หน้าที่ 1: ดึงฟังก์ชันจัดการหมุดมาโชว์
            _buildToiletManager(), 
            
            // หน้าที่ 2: ดึงฟังก์ชันรายงานปัญหามาโชว์
            _buildReportManager(), 
          ],
        ),
      ),
    );
  }

  // ==========================================
  // แท็บที่ 1: ระบบจัดการหมุด (โค้ดเดิมของคุณ)
  // ==========================================
  Widget _buildToiletManager() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('toilets').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("ไม่มีข้อมูลหมุดในระบบเลยครับ"));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            
            String status = data['status'] ?? 'pending';
            bool isBroken = data['isBroken'] ?? false;

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              elevation: 3,
              color: status == 'pending' ? Colors.yellow[50] : (isBroken ? Colors.red[50] : Colors.white),
              child: ListTile(
                leading: data['imageUrl'] != null
                    ? Image.network(data['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                    : Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                title: Text(data['description'] != "" ? data['description'] : 'ไม่มีคำอธิบาย'),
                subtitle: Text("สถานะ: ${status == 'pending' ? '⏳ รออนุมัติ' : (isBroken ? '❌ ชำรุด' : '✅ ปกติ')}\nผู้ปัก: ${data['authorName']}"),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == 'pending')
                      IconButton(
                        icon: Icon(Icons.check_circle, color: Colors.green, size: 30),
                        onPressed: () async => await FirebaseFirestore.instance.collection('toilets').doc(doc.id).update({'status': 'approved', 'isBroken': false}),
                      ),
                    if (status == 'approved')
                      IconButton(
                        icon: Icon(isBroken ? Icons.build : Icons.warning, color: isBroken ? Colors.blue : Colors.orange, size: 30),
                        onPressed: () async => await FirebaseFirestore.instance.collection('toilets').doc(doc.id).update({'isBroken': !isBroken}),
                      ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 30),
                      onPressed: () => FirebaseFirestore.instance.collection('toilets').doc(doc.id).delete(),
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

  // ==========================================
  // แท็บที่ 2: ระบบดูรายงานปัญหา (ส่วนที่สร้างใหม่!)
  // ==========================================
  Widget _buildReportManager() {
    return StreamBuilder(
      // ดึงข้อมูลจาก reports และเรียงจากใหม่ไปเก่า (timestamp)
      stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("ไม่มีการรายงานปัญหาเข้ามาครับ สบายใจได้! ✨", style: TextStyle(fontSize: 16)));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              elevation: 2,
              // ทำขอบสีแดงให้ดูรู้ว่าเป็นเรื่องด่วน
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.redAccent, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red[100],
                  child: Icon(Icons.flag, color: Colors.red),
                ),
                // แสดงสาเหตุที่ user พิมพ์มา
                title: Text("สาเหตุ: ${data['reason']}", style: TextStyle(fontWeight: FontWeight.bold)),
                // แสดงชื่อคนแจ้ง และ ID หมุด (ให้แอดมินเอาไปหาต่อได้)
                subtitle: Text("แจ้งโดย: ${data['reporterName']}\nรหัสหมุด: ${data['toiletId']}"),
                isThreeLine: true,
                
                // ปุ่มเคลียร์ปัญหา (ลบรีพอร์ตทิ้งเมื่อรับทราบแล้ว)
                trailing: IconButton(
                  icon: Icon(Icons.check, color: Colors.green, size: 30),
                  tooltip: "รับทราบและลบทิ้ง",
                  onPressed: () {
                    FirebaseFirestore.instance.collection('reports').doc(doc.id).delete();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}