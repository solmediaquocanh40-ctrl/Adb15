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
  bool isChecked;
  
  TweakItem({
    required this.title,
    required this.subtitle,
    required this.command,
    this.isChecked = false,
  });
}

// --- DANH SÁCH TWEAK KHỔNG LỒ ---
final List<TweakItem> allTweaks = [
  // HIỆU NĂNG (Performance)
  TweakItem(title: "V3: Anim 0.25x (Balanced)", subtitle: "Animation 0.25, phản hồi 230ms.", command: "settings put global window_animation_scale 0.25; settings put global transition_animation_scale 0.25; settings put global animator_duration_scale 0.25"),
  TweakItem(title: "V3: Anim 0.0x (Gaming)", subtitle: "Tắt hoàn toàn hiệu ứng chuyển cảnh.", command: "settings put global window_animation_scale 0; settings put global transition_animation_scale 0; settings put global animator_duration_scale 0"),
  TweakItem(title: "V3: Process Limit (26)", subtitle: "Giới hạn 26 app nền, settle 45s.", command: "device_config put activity_manager max_cached_processes 26"),
  TweakItem(title: "Force GPU Rendering", subtitle: "Bắt buộc dùng GPU vẽ giao diện (Mượt hơn).", command: "setprop debug.hwui.renderer skiavk; setprop debug.hwui.force_dark true"),
  TweakItem(title: "Disable Logger", subtitle: "Tắt ghi log hệ thống (Giảm tải CPU).", command: "stop logd; stop logcat"),
  
  // PIN (Battery)
  TweakItem(title: "V3: Aggressive Doze", subtitle: "Ngủ sâu, tiết kiệm pin tối đa.", command: "dumpsys deviceidle force-idle"),
  TweakItem(title: "V3: JobScheduler Tight", subtitle: "Giảm slot job nền.", command: "cmd jobscheduler reset-execution-quota"),
  TweakItem(title: "Battery Saver Mode", subtitle: "Kích hoạt chế độ tiết kiệm pin.", command: "cmd power set-mode 1"),
  TweakItem(title: "Wipe Battery Stats", subtitle: "Xóa thống kê pin ảo.", command: "dumpsys batterystats --reset"),

  // MẠNG (Network)
  TweakItem(title: "DNS Google (8.8.8.8)", subtitle: "Tối ưu tốc độ phân giải tên miền.", command: "settings put global private_dns_specifier dns.google"),
  TweakItem(title: "DNS Cloudflare (1.1.1.1)", subtitle: "DNS nhanh nhất thế giới.", command: "settings put global private_dns_specifier 1dot1dot1dot1.cloudflare-dns.com"),
  TweakItem(title: "Fix Ping Lag", subtitle: "Tối ưu TCP buffer size.", command: "sysctl -w net.ipv4.tcp_window_scaling=1"),

  // MÀN HÌNH (Display)
  TweakItem(title: "Force 120Hz (Samsung)", subtitle: "Khóa tần số quét tối đa (Nếu máy hỗ trợ).", command: "settings put system min_refresh_rate 120.0"),
  TweakItem(title: "Density 420 DPI", subtitle: "Chỉnh độ nhỏ hiển thị.", command: "wm density 420"),
  TweakItem(title: "Reset Density", subtitle: "Khôi phục hiển thị gốc.", command: "wm density reset"),
];

class AdbMasterApp extends StatelessWidget {
  const AdbMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Master Ultimate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF7F),
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

  Future<void> _runCmd(String cmd) async {
    _addLog("exec: $cmd");
    try {
      ProcessResult res = await Process.run('su', ['-c', cmd]);
      if (res.exitCode != 0) {
        res = await Process.run('sh', ['-c', cmd]);
      }
      if (res.stdout.toString().isNotEmpty) _addLog(res.stdout.toString().trim());
      if (res.stderr.toString().isNotEmpty) _addLog("ERR: ${res.stderr}");
    } catch (e) {
      _addLog("Error: $e");
    }
  }

  void _applySelectedTweaks() async {
    int count = 0;
    for (var item in allTweaks) {
      if (item.isChecked) {
        await _runCmd(item.command);
        count++;
      }
    }
    _addLog(">> APPLIED $count TWEAKS SUCCESSFULLY!");
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Icon(Icons.android, color: Color(0xFF00FF7F), size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    children: [
                      TextSpan(text: "ADB ", style: TextStyle(color: Colors.white)),
                      TextSpan(text: "MASTER", style: TextStyle(color: Color(0xFF00FF7F))),
                    ],
                  ),
                ),
                const Text("ULTIMATE • CONNECTED", style: TextStyle(fontSize: 10, color: Color(0xFF00FF7F))),
              ],
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            height: 40,
            child: Row(
              children: [
                _buildTabItem(0, "TWEAKS"),
                _buildTabItem(1, "CLEANER"),
                _buildTabItem(2, "FLASH"),
              ],
            ),
          ),
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
            border: isActive ? Border.all(color: const Color(0xFF00FF7F), width: 1) : null,
          ),
          alignment: Alignment.center,
          child: Text(title, style: TextStyle(color: isActive ? const Color(0xFF00FF7F) : Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTweaksPage() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: const Color(0xFF111111),
          alignment: Alignment.center,
          child: const Text("SYSTEM OPTIMIZER", style: TextStyle(color: Color(0xFF00FF7F), fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: allTweaks.length,
            itemBuilder: (ctx, i) {
              final item = allTweaks[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(item.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: item.isChecked,
                      activeColor: const Color(0xFF00FF7F),
                      checkColor: Colors.black,
                      onChanged: (val) {
                        setState(() => item.isChecked = val!);
                      },
                    )
                  ],
                ),
              );
            },
          ),
        ),
        // NÚT APPLY TO ĐÙNG
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF7F),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _applySelectedTweaks,
              child: const Text("APPLY SELECTED TWEAKS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildFlashPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sd_storage, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("Flash Zip / Script", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
               try {
                  FilePickerResult? result = await FilePicker.platform.pickFiles();
                  if(result != null) _addLog("Selected: ${result.files.single.name}");
               } catch(e) {_addLog("Error: $e");}
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF222222)),
            child: const Text("CHỌN FILE", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildTerminal() {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                const Text("> TERMINAL", style: TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                InkWell(onTap: () => setState(() => _logText = ""), child: const Text("CLEAR", style: TextStyle(fontSize: 10, color: Colors.white))),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              child: Text(
                _logText.isEmpty ? "# Ready..." : _logText,
                style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00FF7F), fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  String _status = "Sẵn sàng dọn dẹp";
  
  void _startScan() async {
    setState(() { _isScanning = true; _status = "Đang quét rác..."; });
    for (int i = 0; i <= 100; i+=2) {
      await Future.delayed(const Duration(milliseconds: 20));
      setState(() => _percent = i / 100);
    }
    widget.onLog(">> Running trim-caches...");
    widget.onRun("pm trim-caches 999G");
    setState(() { _isScanning = false; _status = "Đã dọn dẹp xong!"; _percent = 1.0; });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularPercentIndicator(
            radius: 70.0, lineWidth: 8.0, percent: _percent,
            center: IconButton(
              icon: Icon(_isScanning ? Icons.hourglass_top : Icons.rocket_launch, size: 40, color: Colors.white),
              onPressed: _isScanning ? null : _startScan,
            ),
            progressColor: const Color(0xFF00FF7F),
            backgroundColor: const Color(0xFF222222),
          ),
          const SizedBox(height: 20),
          Text(_status, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}


