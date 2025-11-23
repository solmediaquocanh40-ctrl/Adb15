import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:percent_indicator/circular_percent_indicator.dart'; // Cần thư viện này trong pubspec

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUIOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF050505),
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const AdbMasterApp());
}

// --- DỮ LIỆU TWEAK (Giống hệt ảnh) ---
class TweakData {
  final String title;
  final String subtitle;
  final String command;
  bool isEnabled;
  TweakData(this.title, this.subtitle, this.command, {this.isEnabled = false});
}

final List<TweakData> tweaksList = [
  TweakData("V3: Anim 0.25x (Balanced)", "Animation 0.25, phản hồi 230ms.", "settings put global window_animation_scale 0.25; settings put global transition_animation_scale 0.25; settings put global animator_duration_scale 0.25"),
  TweakData("V3: Anim 0.20x (Fastest)", "Animation siêu nhanh 0.20, phản hồi 240ms.", "settings put global window_animation_scale 0.2; settings put global transition_animation_scale 0.2; settings put global animator_duration_scale 0.2", isEnabled: true),
  TweakData("V3: Process Limit (26)", "Giới hạn 26 app nền, settle 45s.", "device_config put activity_manager max_cached_processes 26", isEnabled: true),
  TweakData("V3: Aggressive Doze", "Ngủ sâu, tiết kiệm pin tối đa.", "dumpsys deviceidle force-idle"),
  TweakData("V3: JobScheduler Tight", "Giảm slot job nền.", "cmd jobscheduler reset-execution-quota"),
  TweakData("V3: Phantom Proc Cap", "Giới hạn tiến trình ma.", "device_config put activity_manager max_phantom_processes 2147483647"),
  TweakData("Force 120Hz (Samsung)", "Khóa tần số quét tối đa.", "settings put system min_refresh_rate 120.0"),
  TweakData("FSTRIM", "Dọn dẹp bộ nhớ NAND.", "sm f-trim"),
];

class AdbMasterApp extends StatelessWidget {
  const AdbMasterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Master V6',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF80), // Màu xanh Neon đặc trưng
          surface: Color(0xFF121212),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0; // 0: Tweaks, 1: Cleaner, 2: Flash
  String _logText = "";
  final ScrollController _scrollController = ScrollController();

  // --- HÀM CHẠY LỆNH ---
  Future<void> _runCmd(String cmd) async {
    _addLog("root@android: \$ $cmd");
    try {
      // Chạy thử bằng su (Root)
      ProcessResult res = await Process.run('su', ['-c', cmd]);
      if (res.exitCode != 0) {
        // Nếu không root thì chạy thường
        res = await Process.run('sh', ['-c', cmd]);
      }
      
      if (res.stdout.toString().isNotEmpty) _addLog(res.stdout.toString().trim());
      if (res.stderr.toString().isNotEmpty) _addLog("ERR: ${res.stderr}");
      if (res.exitCode == 0) _addLog(">> SUCCESS");
    } catch (e) {
      _addLog("Error: $e");
    }
  }

  void _addLog(String msg) {
    setState(() => _logText += "\n$msg");
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- HEADER ---
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: const Icon(Icons.android, color: Color(0xFF00FF80), size: 28),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: const TextSpan(children: [
              TextSpan(text: "ADB ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              TextSpan(text: "MASTER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF00FF80))),
            ])),
            const Text("V6.1 FIX • CONNECTED", style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
          ],
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 15), child: Icon(Icons.settings, color: Colors.grey))
        ],
      ),

      body: Column(
        children: [
          // --- TAB BAR ---
          Container(
            margin: const EdgeInsets.all(10),
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                _buildTabItem(0, "TWEAKS"),
                _buildTabItem(1, "CLEANER"),
                _buildTabItem(2, "FLASH"),
              ],
            ),
          ),

          // --- BODY CONTENT ---
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildTweaksPage(),
                _CleanerPage(onLog: _addLog, onRun: _runCmd), // Tách riêng trang Cleaner để xử lý animation
                _buildFlashPage(),
              ],
            ),
          ),

          // --- TERMINAL ---
          Container(
            height: 150,
            color: Colors.black,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: const Color(0xFF1A1A1A),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(">_ TERMINAL OUTPUT", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      InkWell(onTap: () => setState(() => _logText = ""), child: const Text("CLEAR", style: TextStyle(fontSize: 10, color: Colors.white))),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _logText.isEmpty ? "# Waiting for commands..." : _logText,
                      style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00FF80), fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    bool active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF252525) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(title, style: TextStyle(
            color: active ? const Color(0xFF00FF80) : Colors.grey,
            fontWeight: FontWeight.bold, fontSize: 12
          )),
        ),
      ),
    );
  }

  // --- TRANG TWEAKS ---
  Widget _buildTweaksPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Tìm nhanh tweaks...",
              filled: true, fillColor: const Color(0xFF121212),
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity, color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: const Text("🚀 FIX LAG V3 (PERFORMANCE)", style: TextStyle(color: Color(0xFF00FF80), fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: tweaksList.length,
            itemBuilder: (ctx, i) {
              final item = tweaksList[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  activeColor: Colors.black,
                  activeTrackColor: const Color(0xFF00FF80),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.black,
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(item.command, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: Colors.grey[800])),
                    ],
                  ),
                  value: item.isEnabled,
                  onChanged: (val) {
                    setState(() => item.isEnabled = val);
                    if(val) _runCmd(item.command);
                  },
                ),
              );
            },
          ),
        )
      ],
    );
  }

  // --- TRANG FLASH ---
  Widget _buildFlashPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!, width: 1, style: BorderStyle.solid) // Nét đứt giả lập
            ),
            child: InkWell(
              onTap: () async {
                try {
                   FilePickerResult? result = await FilePicker.platform.pickFiles();
                   if(result != null) _addLog("Selected: ${result.files.single.name}");
                } catch(e) {_addLog("Error picker: $e");}
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.file_copy, size: 40, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Chọn File Zip / Script", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Nhấn để duyệt file", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F1F1F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
              ),
              onPressed: () => _addLog("Installing... (Need Root)"),
              child: const Text("INSTALL SELECTED", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// --- TRANG CLEANER (LOGIC RIÊNG) ---
class _CleanerPage extends StatefulWidget {
  final Function(String) onLog;
  final Function(String) onRun;
  const _CleanerPage({required this.onLog, required this.onRun});

  @override
  State<_CleanerPage> createState() => _CleanerPageState();
}

class _CleanerPageState extends State<_CleanerPage> {
  bool _isScanning = false;
  double _percent = 0.0;
  String _status = "Smart Cleaner\nDọn dẹp cache hệ thống";
  
  // Danh sách app giả lập để chạy chữ
  final List<String> _dummyApps = ["com.facebook.katana", "com.tiktok.android", "com.google.android.youtube", "com.android.chrome", "system.cache", "dalvik.cache"];

  void _startScan() async {
    setState(() { _isScanning = true; _status = "Scanning..."; });
    
    // 1. CHẠY HIỆU ỨNG (Fake effect)
    for (int i = 0; i <= 100; i+=2) {
      await Future.delayed(const Duration(milliseconds: 30));
      setState(() {
        _percent = i / 100;
        // Random tên app hiện lên cho ngầu
        _status = "Scanning:\n${_dummyApps[Random().nextInt(_dummyApps.length)]}";
      });
    }

    // 2. CHẠY LỆNH THẬT (Real Clean)
    // Lệnh này ép Android giải phóng bộ nhớ mà không cần root
    widget.onLog(">> Executing trim-caches...");
    widget.onRun("pm trim-caches 999G"); 

    setState(() {
      _isScanning = false;
      _status = "Đã dọn dẹp\nsạch sẽ!";
      _percent = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Vòng tròn quét
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                CircularPercentIndicator(
                  radius: 80.0,
                  lineWidth: 10.0,
                  percent: _percent,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isScanning ? Icons.search : Icons.rocket_launch, size: 40, color: Colors.white),
                      const SizedBox(height: 5),
                      Text(_isScanning ? "${(_percent * 100).toInt()}%" : "SCAN", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                  progressColor: const Color(0xFF00FF80),
                  backgroundColor: Colors.grey[800]!,
                  circularStrokeCap: CircularStrokeCap.round,
                  animation: true,
                  animateFromLastPercent: true,
                ),
                const SizedBox(height: 20),
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.5)),
                const SizedBox(height: 20),
                if (!_isScanning)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF80), foregroundColor: Colors.black),
                    onPressed: _startScan,
                    child: const Text("BẮT ĐẦU QUÉT", style: TextStyle(fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Manual Tools
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Text("MANUAL TOOLS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F1F1F), foregroundColor: Colors.white),
                        onPressed: () => widget.onRun("pm trim-caches 999G"),
                        child: const Text("Trim Cache"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F0000), foregroundColor: Colors.redAccent),
                        onPressed: () => widget.onRun("rm -rf /data/local/tmp/*"),
                        child: const Text("Wipe (Root)"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "com.package.name",
                        filled: true, fillColor: Colors.black,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                    )),
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
}


