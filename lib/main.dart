import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdbMasterApp());
}

// --- CẤU TRÚC DỮ LIỆU ---
class TweakItem {
  final String title;
  final String subtitle;
  final String command;
  bool isChecked; // Dùng checkbox thay vì switch
  
  TweakItem({
    required this.title,
    required this.subtitle,
    required this.command,
    this.isChecked = false,
  });
}

// --- DANH SÁCH TWEAK (Giống ảnh) ---
final List<TweakItem> tweaksList = [
  TweakItem(title: "V3: Anim 0.25x (Balanced)", subtitle: "Animation 0.25, phản hồi 230ms.\nsettings put global window_anima...", command: "settings put global window_animation_scale 0.25; settings put global transition_animation_scale 0.25; settings put global animator_duration_scale 0.25"),
  TweakItem(title: "V3: Anim 0.20x (Fastest)", subtitle: "Animation siêu nhanh 0.20, phản hồi 240ms.\nsettings put global window_anima...", command: "settings put global window_animation_scale 0.2; settings put global transition_animation_scale 0.2; settings put global animator_duration_scale 0.2", isChecked: true),
  TweakItem(title: "V3: Process Limit (26)", subtitle: "Giới hạn 26 app nền, settle 45s.\nsettings put global activity_man...", command: "device_config put activity_manager max_cached_processes 26", isChecked: true),
  TweakItem(title: "V3: Aggressive Doze", subtitle: "Ngủ sâu, tiết kiệm pin tối đa.\nsettings put global device_idle_...", command: "dumpsys deviceidle force-idle"),
  TweakItem(title: "V3: JobScheduler Tight", subtitle: "Giảm slot job nền.\nsettings put global jobscheduler...", command: "cmd jobscheduler reset-execution-quota"),
  TweakItem(title: "V3: Phantom Proc Cap", subtitle: "Giới hạn tiến trình phantom.\nsettings put global activity_man...", command: "device_config put activity_manager max_phantom_processes 2147483647"),
];

class AdbMasterApp extends StatelessWidget {
  const AdbMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Master V6.1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF7F), // SpringGreen (Xanh lá chuẩn ADB Master)
          surface: Color(0xFF0A0A0A),
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
  int _tabIndex = 0;
  String _logText = "";
  final ScrollController _scrollController = ScrollController();

  // --- HÀM XỬ LÝ LỆNH ---
  Future<void> _runCmd(String cmd) async {
    _addLog("root@android: \$ $cmd");
    try {
      ProcessResult res = await Process.run('su', ['-c', cmd]);
      if (res.exitCode != 0) {
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
        toolbarHeight: 70,
        title: Row(
          children: [
            // Logo con rồng (giả lập bằng Icon)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.adb, color: Color(0xFF00FF7F), size: 30),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 18, fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                    children: [
                      TextSpan(text: "ADB ", style: TextStyle(color: Colors.white)),
                      TextSpan(text: "MASTER", style: TextStyle(color: Color(0xFF00FF7F))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text("V6.1 FIX", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.circle, size: 6, color: Color(0xFF00FF7F)),
                    const SizedBox(width: 4),
                    const Text("CONNECTED", style: TextStyle(fontSize: 10, color: Color(0xFF00FF7F), fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            )
          ],
        ),
        actions: const [
          Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.dns, color: Colors.grey)),
          Padding(padding: EdgeInsets.only(right: 16, left: 8), child: Icon(Icons.settings, color: Colors.grey)),
        ],
      ),

      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: const [
                SizedBox(width: 12),
                Icon(Icons.search, color: Colors.grey, size: 20),
                SizedBox(width: 12),
                Text("Tìm nhanh tweaks...", style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),

          // --- TAB BAR (Custom) ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
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
          const SizedBox(height: 16),

          // --- CONTENT ---
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildTweaksPage(),
                _CleanerPage(onLog: _addLog, onRun: _runCmd),
                _buildFlashPage(),
              ],
            ),
          ),

          // --- TERMINAL ---
          _buildTerminal(),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    bool isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF222222) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? const Color(0xFF00FF7F) : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // --- PAGE 1: TWEAKS (UI giống ảnh 1) ---
  Widget _buildTweaksPage() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: const Color(0xFF00FF7F), width: 1),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: const Color(0xFF00FF7F).withOpacity(0.1), blurRadius: 10)]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.speed, color: Color(0xFF00FF7F), size: 16),
              SizedBox(width: 8),
              Text("FIX LAG V3 (PERFORMANCE)", style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tweaksList.length,
            itemBuilder: (ctx, i) {
              final item = tweaksList[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text(item.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.4)),
                          const SizedBox(height: 6),
                          Text(item.command.substring(0, min(40, item.command.length)) + "...", style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey[800])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Checkbox Custom giống ảnh
                    InkWell(
                      onTap: () {
                        setState(() => item.isChecked = !item.isChecked);
                        if (item.isChecked) _runCmd(item.command);
                      },
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: item.isChecked ? const Color(0xFF00FF7F) : Colors.transparent,
                          border: Border.all(color: item.isChecked ? const Color(0xFF00FF7F) : Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: item.isChecked ? const Icon(Icons.check, size: 20, color: Colors.black) : null,
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- PAGE 3: FLASH (UI giống ảnh 3) ---
  Widget _buildFlashPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12) // Nét đứt giả lập
            ),
            child: InkWell(
              onTap: () async {
                try {
                  FilePickerResult? result = await FilePicker.platform.pickFiles();
                  if(result != null) _addLog("Selected: ${result.files.single.name}");
                } catch(e) {_addLog("Error: $e");}
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 40, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  const Text("Chọn File Zip / Script", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text("Nhấn để duyệt file", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F1F1F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
              ),
              onPressed: () => _addLog("Starting installation..."),
              child: const Text("INSTALL SELECTED", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTerminal() {
    return Container(
      height: 140,
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF111111),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                const Text("TERMINAL OUTPUT", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(2)),
                   child: const Text("COPY", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                InkWell(
                   onTap: () => setState(() => _logText = ""),
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                     decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(2)),
                     child: const Text("CLEAR", style: TextStyle(fontSize: 10, color: Colors.grey)),
                   ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              child: Text(
                _logText.isEmpty ? "# Logs will appear here..." : _logText,
                style: TextStyle(fontFamily: 'monospace', color: Colors.grey[700], fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PAGE 2: CLEANER (UI giống ảnh 2) ---
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
  String _title = "Smart Cleaner";
  String _subTitle = "Dọn dẹp cache hệ thống";
  
  final List<String> _dummyApps = ["com.facebook.katana", "com.tiktok.android", "com.google.android.youtube", "com.android.chrome", "system.cache", "dalvik.cache"];

  void _startScan() async {
    setState(() { _isScanning = true; _title = "Scanning..."; _subTitle = "Đang phân tích..."; });
    
    for (int i = 0; i <= 100; i+=2) {
      await Future.delayed(const Duration(milliseconds: 25));
      setState(() {
        _percent = i / 100;
        _subTitle = _dummyApps[Random().nextInt(_dummyApps.length)];
      });
    }
    
    widget.onLog(">> Executing Smart Clean...");
    widget.onRun("pm trim-caches 999G"); 

    setState(() {
      _isScanning = false;
      _title = "Hoàn tất";
      _subTitle = "Đã giải phóng bộ nhớ";
      _percent = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Card to Cleaner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircularPercentIndicator(
                  radius: 50.0,
                  lineWidth: 4.0,
                  percent: _percent,
                  center: InkWell( // Chạm vào icon là chạy
                    onTap: _isScanning ? null : _startScan,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.rocket_launch, size: 30, color: Colors.white),
                    ),
                  ),
                  progressColor: const Color(0xFF00FF7F),
                  backgroundColor: const Color(0xFF222222),
                  circularStrokeCap: CircularStrokeCap.round,
                  animation: true,
                  animateFromLastPercent: true,
                ),
                const SizedBox(height: 16),
                Text(_title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                const SizedBox(height: 4),
                Text(_subTitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                // Fake Progress Bar
                Container(
                   margin: const EdgeInsets.symmetric(horizontal: 40),
                   height: 4,
                   child: LinearProgressIndicator(
                     value: _isScanning ? _percent : 0, 
                     backgroundColor: const Color(0xFF222222),
                     valueColor: const AlwaysStoppedAnimation(Color(0xFF00FF7F)),
                   ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Manual Tools Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF0F0F0F), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Text("MANUAL TOOLS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                        ),
                        onPressed: () => widget.onRun("pm trim-caches 999G"),
                        child: const Text("Trim Cache", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF330000),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide.none)
                        ),
                        onPressed: () => widget.onRun("rm -rf /data/local/tmp/*"),
                        child: const Text("Wipe (Root)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
                      alignment: Alignment.centerLeft,
                      child: const Text("com.package.name", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    )),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF7F),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                        ),
                        onPressed: () {},
                        child: const Text("CLEAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
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


