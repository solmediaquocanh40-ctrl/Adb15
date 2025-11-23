import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUIOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF050505),
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const AdbMasterApp());
}

// ===============================
// 1. DỮ LIỆU & CẤU HÌNH (TWEAKS)
// ===============================

class TweakItem {
  final String id;
  final String title;
  final String subtitle;
  final String command;
  bool isEnabled;

  TweakItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.command,
    this.isEnabled = false,
  });
}

// KHO TWEAK KHỔNG LỒ (Mô phỏng 200 lệnh)
final List<TweakItem> allTweaks = [
  TweakItem(id: "v3_anim_balanced", title: "V3: Anim 0.25x (Balanced)", subtitle: "Animation 0.25, phản hồi 230ms. Mượt mà.", command: "settings put global window_animation_scale 0.25; settings put global transition_animation_scale 0.25; settings put global animator_duration_scale 0.25"),
  TweakItem(id: "v3_anim_fastest", title: "V3: Anim 0.10x (Fastest)", subtitle: "Animation siêu nhanh 0.10, phản hồi tức thì.", command: "settings put global window_animation_scale 0.1; settings put global transition_animation_scale 0.1; settings put global animator_duration_scale 0.1", isEnabled: true),
  TweakItem(id: "v3_proc_limit", title: "V3: Process Limit (26)", subtitle: "Giới hạn 26 app nền, settle 45s.", command: "device_config put activity_manager max_cached_processes 26", isEnabled: true),
  TweakItem(id: "v3_doze", title: "V3: Aggressive Doze", subtitle: "Ngủ sâu, tiết kiệm pin tối đa khi tắt màn.", command: "dumpsys deviceidle force-idle"),
  TweakItem(id: "v3_jobs", title: "V3: JobScheduler Tight", subtitle: "Giảm slot job nền, tránh đánh thức máy.", command: "cmd jobscheduler reset-execution-quota"),
  TweakItem(id: "v3_phantom", title: "V3: Phantom Proc Cap", subtitle: "Giới hạn tiến trình ma (Phantom Process).", command: "device_config put activity_manager max_phantom_processes 2147483647"),
  // Performance Tweaks
  TweakItem(id: "perf_fstrim", title: "FSTRIM (Dọn dẹp bộ nhớ)", subtitle: "Tối ưu hóa NAND Flash, giảm lag.", command: "sm f-trim"),
  TweakItem(id: "perf_dexopt", title: "Force DexOpt (Speed)", subtitle: "Biên dịch lại app (Tốn pin nhưng mở app nhanh).", command: "cmd package bg-dexopt-job"),
  TweakItem(id: "perf_rendering", title: "GPU Rendering", subtitle: "Bắt buộc dùng GPU để vẽ giao diện.", command: "setprop debug.hwui.renderer skiavk"),
  // Network Tweaks
  TweakItem(id: "net_dns_google", title: "DNS Google", subtitle: "Đổi DNS sang 8.8.8.8 (Yêu cầu Android 9+).", command: "settings put global private_dns_specifier dns.google"),
  TweakItem(id: "net_dns_cf", title: "DNS Cloudflare", subtitle: "Đổi DNS sang 1.1.1.1 (Nhanh hơn).", command: "settings put global private_dns_specifier 1dot1dot1dot1.cloudflare-dns.com"),
  TweakItem(id: "net_tcp", title: "TCP BBR Congestion", subtitle: "Tối ưu thuật toán mạng (Cần Kernel hỗ trợ).", command: "sysctl -w net.ipv4.tcp_congestion_control=bbr"),
  // Display Tweaks
  TweakItem(id: "disp_90hz", title: "Force 90Hz", subtitle: "Khóa tần số quét màn hình 90Hz.", command: "settings put system min_refresh_rate 90.0; settings put system peak_refresh_rate 90.0"),
  TweakItem(id: "disp_120hz", title: "Force 120Hz", subtitle: "Khóa tần số quét màn hình 120Hz.", command: "settings put system min_refresh_rate 120.0; settings put system peak_refresh_rate 120.0"),
  // Gaming Mode
  TweakItem(id: "game_driver", title: "Force Game Driver", subtitle: "Bắt buộc dùng Driver đồ họa game cho toàn hệ thống.", command: "settings put global game_driver_all_apps 1"),
  TweakItem(id: "game_touch", title: "Touch Sensitivity", subtitle: "Tăng độ nhạy cảm ứng (Thử nghiệm).", command: "settings put system pointer_speed 7"),
  // Battery
  TweakItem(id: "batt_stats", title: "Wipe Battery Stats", subtitle: "Xóa thống kê pin ảo.", command: "dumpsys batterystats --reset"),
  TweakItem(id: "batt_saver", title: "Enable Battery Saver", subtitle: "Bật tiết kiệm pin hệ thống.", command: "cmd power set-mode 1"),
];

// ===============================
// 2. GIAO DIỆN CHÍNH
// ===============================

class AdbMasterApp extends StatelessWidget {
  const AdbMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Master V6.1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505), // Đen tuyền
        cardColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF80), // Xanh Neon ADB Master
          secondary: Color(0xFF00E676),
          surface: Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF050505),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0; // 0: Tweaks, 1: Cleaner, 2: Flash
  String _terminalLog = "";
  final ScrollController _consoleScroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<TweakItem> _filteredTweaks = allTweaks;

  // Hàm ghi log ra Terminal
  void _log(String msg) {
    setState(() {
      _terminalLog += "\n$ msg";
    });
    // Auto scroll xuống cuối
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_consoleScroll.hasClients) {
        _consoleScroll.jumpTo(_consoleScroll.position.maxScrollExtent);
      }
    });
  }

  // Hàm chạy lệnh Shell
  Future<void> _runShell(String cmd) async {
    _log("root@android: \$ $cmd");
    try {
      // Thử chạy bằng su (Root) trước
      ProcessResult result = await Process.run('su', ['-c', cmd]);
      
      // Nếu thất bại (exitCode != 0) thì chạy bằng sh (User)
      if (result.exitCode != 0) {
        _log("Root denied. Trying user shell...");
        result = await Process.run('sh', ['-c', cmd]);
      }

      if (result.stdout.toString().isNotEmpty) _log(result.stdout.toString().trim());
      if (result.stderr.toString().isNotEmpty) _log("ERR: ${result.stderr.toString().trim()}");
      if (result.exitCode == 0) _log(">> SUCCESS");
      
    } catch (e) {
      _log("EXCEPTION: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- APP BAR ---
      appBar: AppBar(
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.network("https://cdn-icons-png.flaticon.com/512/25/25231.png", color: const Color(0xFF00FF80)), // Logo GitHub tạm
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(text: "ADB ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
                  TextSpan(text: "MASTER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF00FF80))),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(3)),
                  child: const Text("V6.1 FIX", style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.circle, size: 8, color: Color(0xFF00FF80)),
                const Text(" CONNECTED", style: TextStyle(fontSize: 10, color: Color(0xFF00FF80), fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.dns, color: Colors.grey), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings, color: Colors.grey), onPressed: () {}),
        ],
      ),

      body: Column(
        children: [
          // --- TAB SELECTOR ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                _buildTabBtn(0, "TWEAKS"),
                _buildTabBtn(1, "CLEANER"),
                _buildTabBtn(2, "FLASH"),
              ],
            ),
          ),

          // --- MAIN CONTENT AREA ---
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildTweaksTab(),
                _buildCleanerTab(),
                _buildFlashTab(),
              ],
            ),
          ),

          // --- TERMINAL (BOTTOM SHEET) ---
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF080808),
              border: Border(top: BorderSide(color: Color(0xFF00FF80), width: 1)),
            ),
            child: Column(
              children: [
                // Terminal Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: const Color(0xFF121212),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text("TERMINAL OUTPUT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const Spacer(),
                      _buildSmallBtn("COPY", () {}),
                      const SizedBox(width: 8),
                      _buildSmallBtn("CLEAR", () => setState(() => _terminalLog = "")),
                    ],
                  ),
                ),
                // Terminal Log
                Expanded(
                  child: SingleChildScrollView(
                    controller: _consoleScroll,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _terminalLog.isEmpty ? "# Logs will appear here..." : _terminalLog,
                      style: const TextStyle(fontFamily: "monospace", fontSize: 11, color: Color(0xFF00FF80), height: 1.3),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGETS CON ---

  Widget _buildTabBtn(int index, String text) {
    bool isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1F1F1F) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: isActive ? Border.all(color: Colors.white12) : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isActive ? const Color(0xFF00FF80) : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBtn(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.white)),
      ),
    );
  }

  // --- TAB 1: TWEAKS ---
  Widget _buildTweaksTab() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _filteredTweaks = allTweaks.where((t) => t.title.toLowerCase().contains(val.toLowerCase())).toList();
              });
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: "Tìm nhanh tweaks...",
              hintStyle: TextStyle(color: Colors.grey[700]),
              filled: true,
              fillColor: const Color(0xFF121212),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.black,
          child: const Center(child: Text("🚀 FIX LAG V3 (PERFORMANCE)", style: TextStyle(color: Color(0xFF00FF80), fontWeight: FontWeight.bold, fontSize: 12))),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _filteredTweaks.length,
            itemBuilder: (ctx, i) {
              final t = _filteredTweaks[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: SwitchListTile(
                  activeColor: Colors.black,
                  activeTrackColor: const Color(0xFF00FF80),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.black,
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(t.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(t.command, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[800], fontFamily: 'monospace')),
                    ],
                  ),
                  value: t.isEnabled,
                  onChanged: (val) {
                    setState(() => t.isEnabled = val);
                    _runShell(t.command);
                  },
                ),
              );
            },
          ),
        )
      ],
    );
  }

  // --- TAB 2: CLEANER ---
  Widget _buildCleanerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Big Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1E1E),
                    border: Border.all(color: const Color(0xFF00FF80).withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.rocket_launch, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 15),
                const Text("Smart Cleaner", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Dọn dẹp cache hệ thống", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                LinearProgressIndicator(value: 0.7, backgroundColor: Colors.grey[900], valueColor: const AlwaysStoppedAnimation(Color(0xFF00FF80))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Manual Tools
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text("MANUAL TOOLS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F1F1F), foregroundColor: Colors.white),
                        onPressed: () => _runShell("pm trim-caches 999G"),
                        child: const Text("Trim Cache"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F0000), foregroundColor: Colors.redAccent),
                        onPressed: () => _runShell("rm -rf /data/local/tmp/*"),
                        child: const Text("Wipe (Root)"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "com.package.name",
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF80), foregroundColor: Colors.black),
                      onPressed: () {},
                      child: const Text("CLEAN", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- TAB 3: FLASH ---
  Widget _buildFlashTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 300,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, style: BorderStyle.solid),
            ),
            child: InkWell(
              onTap: () async {
                 FilePickerResult? result = await FilePicker.platform.pickFiles();
                 if (result != null) {
                   _log("Selected: ${result.files.single.name}");
                 }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_present, size: 50, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text("Chọn File Zip / Script", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  const Text("Nhấn để duyệt file", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 300,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F1F1F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _log("Starting installation..."),
              child: const Text("INSTALL SELECTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}


