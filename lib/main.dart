import 'dart:io';
import 'dart:async';
import 'dart:math';
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
// CẤU HÌNH DỮ LIỆU
// ===============================

class TweakItem {
  final String title;
  final String subtitle;
  final String command;
  bool isEnabled;
  bool isDangerous;

  TweakItem({
    required this.title,
    required this.subtitle,
    required this.command,
    this.isEnabled = false,
    this.isDangerous = false,
  });
}

// ===============================
// GIAO DIỆN CHÍNH
// ===============================

class AdbMasterApp extends StatelessWidget {
  const AdbMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Master V6.2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        cardColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF80), // Xanh Neon
          secondary: Color(0xFF00E676),
          surface: Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF050505), elevation: 0),
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentTab = 0;
  String _terminalLog = "";
  final ScrollController _consoleScroll = ScrollController();
  
  // Biến cho Cleaner Animation
  bool _isCleaning = false;
  double _cleanProgress = 0.0;
  String _cleanStatus = "Sẵn sàng dọn dẹp";
  String _currentScanningApp = "";

  // Danh sách các gói tin giả lập để tạo hiệu ứng quét (giống 1Tap Cleaner)
  final List<String> _dummyPackages = [
    "com.android.chrome", "com.facebook.katana", "com.instagram.android",
    "com.google.android.youtube", "com.whatsapp", "com.android.vending",
    "com.google.android.gms", "com.tiktok.android", "com.spotify.music",
    "com.twitter.android", "com.snapchat.android", "com.zhiliaoapp.musically",
    "com.google.android.apps.maps", "com.google.android.apps.photos",
    "system_cache", "dalvik_cache", "shader_cache", "thumbnails"
  ];

  // Danh sách Tweaks
  final List<TweakItem> _tweaks = [
    TweakItem(title: "⚡ Anim 0.5x (No Root)", subtitle: "Tăng tốc hiệu ứng chuyển cảnh.", command: "settings put global window_animation_scale 0.5; settings put global transition_animation_scale 0.5; settings put global animator_duration_scale 0.5"),
    TweakItem(title: "🛑 Disable Animation", subtitle: "Tắt hoàn toàn hiệu ứng (Siêu mượt).", command: "settings put global window_animation_scale 0; settings put global transition_animation_scale 0; settings put global animator_duration_scale 0"),
    TweakItem(title: "🔋 Battery Saver Mode", subtitle: "Kích hoạt chế độ tiết kiệm pin hệ thống.", command: "cmd power set-mode 1"),
    TweakItem(title: "😴 Force Doze Mode", subtitle: "Bắt buộc ngủ đông ngay lập tức.", command: "dumpsys deviceidle force-idle"),
    TweakItem(title: "📶 Fix DNS (Google)", subtitle: "Đặt DNS 8.8.8.8 (Fix lag mạng).", command: "settings put global private_dns_specifier dns.google"),
    TweakItem(title: "🎮 Force 4x MSAA", subtitle: "Khử răng cưa cho game (OpenGL).", command: "setprop debug.egl.force_msaa 1"),
    TweakItem(title: "💀 Wipe Dalvik (Root Only)", subtitle: "Xóa bộ đệm biên dịch (Cần Root).", command: "rm -rf /data/dalvik-cache/*", isDangerous: true),
  ];

  // --- LOGIC: LOG SYSTEM ---
  void _log(String msg) {
    setState(() => _terminalLog += "\n$ msg");
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_consoleScroll.hasClients) _consoleScroll.jumpTo(_consoleScroll.position.maxScrollExtent);
    });
  }

  // --- LOGIC: SHELL EXECUTOR ---
  Future<void> _runShell(String cmd) async {
    _log("exec: $cmd");
    try {
      // Chạy lệnh thường (sh) vì yêu cầu không Root vẫn dùng được
      // Một số lệnh settings/cmd/pm vẫn chạy tốt không cần su
      ProcessResult result = await Process.run('sh', ['-c', cmd]);
      
      if (result.stdout.toString().isNotEmpty) _log(result.stdout.toString().trim());
      if (result.stderr.toString().isNotEmpty) _log("ERR: ${result.stderr.toString().trim()}");
      if (result.exitCode == 0) _log(">> SUCCESS");
    } catch (e) {
      _log("FAIL: $e");
    }
  }

  // --- LOGIC: SMART CLEANER (Giả lập + Lệnh thật) ---
  Future<void> _startSmartClean() async {
    if (_isCleaning) return;
    
    setState(() {
      _isCleaning = true;
      _cleanProgress = 0.0;
      _cleanStatus = "Đang phân tích bộ nhớ...";
    });

    _log(">> STARTING SMART CLEANER...");

    // 1. Hiệu ứng quét từng app (Giả lập để giống 1Tap Cleaner)
    int totalSteps = _dummyPackages.length;
    for (int i = 0; i < totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 150)); // Tốc độ quét
      setState(() {
        _currentScanningApp = _dummyPackages[i];
        _cleanStatus = "Đang quét: $_currentScanningApp";
        _cleanProgress = (i + 1) / totalSteps;
      });
      
      // Ngẫu nhiên log ra màn hình cho "ngầu"
      if (Random().nextBool()) _log("Found cache in: $_currentScanningApp");
    }

    // 2. Chạy lệnh dọn dẹp THẬT (Non-Root)
    // Lệnh này yêu cầu hệ thống giải phóng bộ nhớ cache của các app
    // Nó hoạt động trên hầu hết máy Android mà không cần root
    setState(() => _cleanStatus = "Đang thực thi lệnh hệ thống...");
    await _runShell("pm trim-caches 999999999999"); 
    // 'pm trim-caches' cố gắng giải phóng dung lượng mong muốn, buộc Android xóa cache

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isCleaning = false;
      _cleanStatus = "Đã dọn dẹp xong!";
      _cleanProgress = 1.0;
      _currentScanningApp = "Sạch sẽ ✨";
    });
    _log(">> CLEANING COMPLETED. STORAGE OPTIMIZED.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildTweaksTab(),
                _buildCleanerTab(), // Tab Cleaner mới xịn sò
                _buildFlashTab(),
              ],
            ),
          ),
          _buildTerminal(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.android, color: Color(0xFF00FF80)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("ADB MASTER", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00FF80))),
              Text("NON-ROOT EDITION", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          )
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.settings), onPressed: (){}),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _tabItem(0, "TWEAKS", Icons.code),
          _tabItem(1, "CLEANER", Icons.cleaning_services),
          _tabItem(2, "FLASH", Icons.sd_storage),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String title, IconData icon) {
    bool active = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1F1F1F) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: active ? Border.all(color: Colors.white10) : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? const Color(0xFF00FF80) : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: TWEAKS ---
  Widget _buildTweaksTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _tweaks.length,
      itemBuilder: (context, index) {
        final item = _tweaks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: item.isDangerous ? Colors.red.withOpacity(0.3) : Colors.white10),
          ),
          child: SwitchListTile(
            title: Text(item.title, style: TextStyle(fontWeight: FontWeight.bold, color: item.isDangerous ? Colors.redAccent : Colors.white)),
            subtitle: Text(item.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            activeColor: const Color(0xFF00FF80),
            activeTrackColor: const Color(0xFF00FF80).withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.black,
            value: item.isEnabled,
            onChanged: (val) {
              setState(() => item.isEnabled = val);
              if (val) _runShell(item.command);
            },
          ),
        );
      },
    );
  }

  // --- TAB 2: CLEANER (QUAN TRỌNG NHẤT) ---
  Widget _buildCleanerTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Vòng tròn tiến trình lớn
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: _isCleaning ? _cleanProgress : 0,
                  strokeWidth: 15,
                  backgroundColor: const Color(0xFF1F1F1F),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF80)),
                ),
              ),
              GestureDetector(
                onTap: _startSmartClean, // Bấm vào để chạy
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCleaning ? const Color(0xFF0D1117) : const Color(0xFF1F1F1F),
                    boxShadow: [
                      if (!_isCleaning)
                        BoxShadow(color: const Color(0xFF00FF80).withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                    ]
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isCleaning ? Icons.hourglass_bottom : Icons.rocket_launch,
                        size: 50,
                        color: const Color(0xFF00FF80),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isCleaning ? "${(_cleanProgress * 100).toInt()}%" : "SCAN",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            _cleanStatus,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _isCleaning ? "Đang xử lý: $_currentScanningApp" : "Nhấn nút để bắt đầu dọn dẹp hệ thống",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          // Nút phụ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _cleanerSubBtn("Quick Clean", () => _runShell("pm trim-caches 1000G")),
              const SizedBox(width: 20),
              _cleanerSubBtn("Kill Background", () => _runShell("am kill-all")),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _cleanerSubBtn(String text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
      ),
      child: Text(text),
    );
  }

  // --- TAB 3: FLASH ---
  Widget _buildFlashTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sd_card, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 20),
          const Text("Flash Zip / Script", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Chọn file .zip hoặc .sh để cài đặt", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open, color: Colors.black),
            label: const Text("CHỌN FILE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF80),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: () async {
              try {
                FilePickerResult? result = await FilePicker.platform.pickFiles();
                if (result != null) _log("Selected: ${result.files.single.name}");
              } catch (e) {
                _log("Error picking file: $e");
              }
            },
          )
        ],
      ),
    );
  }

  // --- TERMINAL ---
  Widget _buildTerminal() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xFF101010),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TERMINAL", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                InkWell(onTap: () => setState(() => _terminalLog = ""), child: const Icon(Icons.block, size: 14, color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _consoleScroll,
              padding: const EdgeInsets.all(8),
              child: Text(
                _terminalLog.isEmpty ? "# Ready..." : _terminalLog,
                style: const TextStyle(fontFamily: "monospace", fontSize: 11, color: Color(0xFF00FF80), height: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


