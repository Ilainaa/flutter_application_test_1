import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── สีธีมหลัก (ตรงกับ home_page.dart) ──
const Color _pink = Color(0xFFE91E8C);
const Color _lightPink = Color(0xFFFCE4EC);
const Color _softPink = Color(0xFFF8BBD0);
const Color _deepPink = Color(0xFFC2185B);

// ── Key สำหรับ SharedPreferences ──
const String _kTutorialSeen = 'tutorial_seen_v1';

// ── ข้อมูลแต่ละสไลด์ ──
class _TutorialStep {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;

  const _TutorialStep({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
  });
}

const List<_TutorialStep> _steps = [
  _TutorialStep(
    icon: Icons.wc_rounded,
    iconColor: Colors.white,
    iconBg: _pink,
    title: "ยินดีต้อนรับสู่ Hong Nam! 🎉",
    description:
        "แอปช่วยค้นหาห้องน้ำสาธารณะใกล้คุณได้อย่างง่ายดาย\nมาดูวิธีใช้งานปุ่มต่าง ๆ กันเลยค่ะ",
  ),
  _TutorialStep(
    icon: Icons.search_rounded,
    iconColor: _pink,
    iconBg: _lightPink,
    title: "🔍 ช่องค้นหาสถานที่",
    description:
        "พิมพ์ชื่อสถานที่ที่ต้องการ แล้วกดปุ่มแว่นขยาย\nหรือกด Enter เพื่อให้แผนที่เลื่อนไปยังสถานที่นั้นได้เลยค่ะ",
  ),
  _TutorialStep(
    icon: Icons.layers_rounded,
    iconColor: Colors.white,
    iconBg: Color(0xFF5C6BC0),
    title: "🗺️ ปุ่มเปลี่ยนประเภทแผนที่",
    description:
        "กดปุ่มนี้เพื่อสลับระหว่าง\n• แผนที่ปกติ (Normal)\n• แผนที่ดาวเทียม (Satellite/Hybrid)\nเลือกแบบที่มองง่ายที่สุดสำหรับคุณค่ะ",
  ),
  _TutorialStep(
    icon: Icons.add_location_alt_rounded,
    iconColor: Colors.white,
    iconBg: _pink,
    title: "📍 ปุ่มปักหมุดห้องน้ำใหม่",
    description:
        "กดปุ่มนี้เพื่อเพิ่มห้องน้ำที่คุณรู้จักลงในแผนที่!\nแผนที่จะเข้าสู่โหมดเล็ง — เลื่อนแผนที่ไปยังจุดที่ต้องการ\nแล้วกด \"เล็งตรงนี้!\" เพื่อกรอกรายละเอียดค่ะ",
  ),
  _TutorialStep(
    icon: Icons.my_location_rounded,
    iconColor: _pink,
    iconBg: _lightPink,
    title: "📡 ปุ่มตำแหน่งของฉัน",
    description:
        "กดปุ่มนี้เพื่อให้แผนที่กลับมาโฟกัสที่ตำแหน่งปัจจุบันของคุณได้ทันที\nสะดวกมากเมื่อคุณเลื่อนแผนที่ออกไปไกลค่ะ",
  ),
  _TutorialStep(
    icon: Icons.person_rounded,
    iconColor: Colors.white,
    iconBg: Color(0xFF26A69A),
    title: "👤 ปุ่มโปรไฟล์",
    description:
        "กดเพื่อดูและแก้ไขข้อมูลส่วนตัวของคุณ\nรวมถึงดูรายการห้องน้ำที่คุณเคยปักหมุดไว้ได้ค่ะ",
  ),
  _TutorialStep(
    icon: Icons.location_on_rounded,
    iconColor: Colors.white,
    iconBg: Colors.green,
    title: "🚻 หมุดบนแผนที่",
    description:
        "• 🟢 หมุดเขียว = ห้องน้ำฟรี\n• 🟠 หมุดส้ม = ห้องน้ำเสียเงิน\n• 🔴 หมุดแดง = ชำรุด/ปิดซ่อม\n\nแตะที่หมุดเพื่อดูรายละเอียด ให้คะแนน และนำทางได้เลยค่ะ",
  ),
];

/// เรียกใช้ฟังก์ชันนี้ใน initState ของ HomePage
/// จะแสดง Dialog เฉพาะครั้งแรกที่ผู้ใช้เปิดแอป
Future<void> showTutorialIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final bool alreadySeen = prefs.getBool(_kTutorialSeen) ?? false;
  if (alreadySeen) return;

  // รอให้ Widget build เสร็จก่อน
  await Future.delayed(Duration.zero);

  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _TutorialDialog(),
  );
}

// ── Widget Dialog หลัก ──
class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog();

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _markSeenAndClose() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialSeen, true);
    if (mounted) Navigator.of(context).pop();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _markSeenAndClose();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _steps.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header gradient ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_pink, _deepPink],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline_rounded,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "วิธีใช้งาน Hong Nam",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // ปุ่มข้าม (ข้ามทั้งหมด)
                TextButton(
                  onPressed: _markSeenAndClose,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "ข้าม",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // ── PageView เนื้อหา ──
          SizedBox(
            height: 330,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _steps.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (ctx, index) {
                final step = _steps[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
                  child: Column(
                    children: [
                      // ── ไอคอน ──
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: step.iconBg,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: step.iconBg.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(step.icon, color: step.iconColor, size: 36),
                      ),
                      const SizedBox(height: 18),

                      // ── ชื่อสไลด์ ──
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _deepPink,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── คำอธิบาย ──
                      Text(
                        step.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Dot Indicators ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) {
              final bool active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? _pink : _softPink,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // ── ปุ่มล่าง ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                // ── ปุ่มย้อนกลับ (ซ้าย) ──
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _deepPink,
                        side: const BorderSide(color: _softPink, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text("◀  ก่อนหน้า",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),

                if (_currentPage > 0) const SizedBox(width: 12),

                // ── ปุ่มถัดไป / เริ่มใช้งาน (ขวา) ──
                Expanded(
                  flex: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_pink, _deepPink],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _pink.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        isLastPage ? "🎉 เริ่มใช้งานเลย!" : "ถัดไป  ▶",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── ปุ่ม "ไม่ต้องแสดงอีก" ──
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: _markSeenAndClose,
              child: Text(
                "✓ เข้าใจแล้ว ไม่ต้องแสดงอีก",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[400],
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.grey[400],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}