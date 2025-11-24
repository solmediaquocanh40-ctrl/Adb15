import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdbMasterApp());
}

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

final List<TweakItem> allTweaks = [
  TweakItem(title: "V3: Anim 0.25x (Balanced)", subtitle: "Animation 0.25, phản hồi 230ms.", command: "settings put global window_animation_scale 0.25; settings put global transition_animation_scale 0.25; settings put global animator_duration_scale 0.25"),
  TweakItem(title: "V3: Anim 0.0x (Gaming)", subtitle: "Tắt hoàn toàn hiệu ứng.", command: "settings put global window_animation_scale 0; settings put global transition_animation_scale 0; settings put global animator_duration_scale 0"),
  TweakItem(title: "Force GPU Rendering", subtitle: "Bắt buộc dùng GPU vẽ giao diện.", command: "setprop debug.hwui.renderer skiavk; setprop debug.hwui.force_dark true"),
  TweakItem(title: "Disable Logger", subtitle: "Tắt ghi log (Tăng tốc CPU).", command: "stop logd; stop logcat"),
  TweakItem(title: "FSTRIM", subtitle: "Tối ưu bộ nhớ (Có thể chạy không Root).", command: "sm f-trim"),
  TweakItem(title: "Reboot", subtitle: "Khởi động lại.", command: "reboot"),
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
        colorScheme: const ColorScheme.dark(primary: Color(0xFF00FF7F), surface: Color(0xFF0A0A0A)),
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
  String _selectedFileName = "Chưa chọn file nào";
  final ScrollController _scrollController = ScrollController();

  // --- HÀM CHẠY LỆNH (FIX MẠNH) ---
  Future<void> _runCmd(String cmd) async {
    _addLog("> Exec: $cmd");
    try {
      // Thử chạy với 'sh -c' trước để test lệnh thường
      // Nếu lệnh cần root, ta dùng 'su -c'
      // Lưu ý: Trên Android thật, 'su' chỉ có khi đã Root
      ProcessResult res;
      try {
         // Ưu tiên chạy su nếu có thể
         res = await Process.run('su', ['-c', cmd]);
      } catch (e) {
         // Không có su thì chạy sh
         res = await Process.run('sh', ['-c', cmd]);
      }

      if (res.stdout.toString().isNotEmpty) _addLog(res.stdout.toString().trim());
      if (res.stderr.toString().isNotEmpty) _addLog("Msg: ${res.stderr.toString().trim()}");
      if (res.exitCode == 0) _addLog(">> SUCCESS");
      
    } catch (e) {
      _addLog("Error: $e");
    }
  }

  // --- HÀM CHỌN FILE & FLASH ---
  Future<void> _pickAndFlashFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        String? filePath = result.files.single.path;
        String fileName = result.files.single.name;
        
        setState(() {
          _selectedFileName = fileName;
        });
        
        _addLog("Selected: $filePath");

        // Logic Flash (Mô phỏng hoặc thực thi nếu là .sh)
        if (fileName.endsWith(".sh")) {
           _addLog(">> Detected Shell Script. Executing...");
           // Cấp quyền thực thi
           await _runCmd("chmod +x $filePath");
           // Chạy script
           await _runCmd("sh $filePath");
        } else if (fileName.endsWith(".zip")) {
           _addLog(">> Detected ZIP. Flashing via Magisk (if supported)...");
           // Lệnh giả lập flash module magisk (cần root thật để chạy)
           await _runCmd("magisk --install-module $filePath");
        } else {
           _addLog(">> Unknown file type. Cannot flash directly.");
        }

      } else {
        _addLog(">> File selection canceled.");
      }
    } catch (e) {
      _addLog("Picker Error: $e");
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
    if (count > 0) _addLog(">> FINISHED $count COMMANDS.");
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
        title: Row(children: [
          const Icon(Icons.android, color: Color(0xFF00FF7F), size: 30),
          const SizedBox(width: 10),
          const Text("ADB MASTER ULTIMATE", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00FF7F))),
        ]),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            height: 40,
            child: Row(children: [_buildTab(0, "TWEAKS"), _buildTab(1, "CLEANER"), _buildTab(2, "FLASH")]),
          ),
          Expanded(child: IndexedStack(index: _tabIndex, children: [
            _buildTweaksPage(),
            _CleanerPage(onLog: _addLog, onRun: _runCmd),
            _buildFlashPage(), // Tab Flash đã được cập nhật
          ])),
          _buildTerminal(),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title) {
    bool active = _tabIndex == index;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF222222) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFF00FF7F)) : null,
        ),
        alignment: Alignment.center,
        child: Text(title, style: TextStyle(color: active ? const Color(0xFF00FF7F) : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    ));
  }

  Widget _buildTweaksPage() {
    return Column(children: [
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allTweaks.length,
        itemBuilder: (ctx, i) {
          final item = allTweaks[i];
          return Card(
            color: const Color(0xFF0F0F0F),
            child: CheckboxListTile(
              activeColor: const Color(0xFF00FF7F),
              checkColor: Colors.black,
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              value: item.isChecked,
              onChanged: (v) => setState(() => item.isChecked = v!),
            ),
          );
        },
      )),
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF7F), foregroundColor: Colors.black),
          onPressed: _applySelectedTweaks,
          child: const Text("APPLY SELECTED TWEAKS", style: TextStyle(fontWeight: FontWeight.w900)),
        )),
      )
    ]);
  }

  // --- TAB FLASH ĐÃ NÂNG CẤP ---
  Widget _buildFlashPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              children: [
                const Icon(Icons.file_present, size: 50, color: Color(0xFF00FF7F)),
                const SizedBox(height: 15),
                Text(_selectedFileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 5),
                const Text("Support: .zip, .sh", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text("CHỌN FILE & FLASH"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F1F1F), foregroundColor: Colors.white),
              onPressed: _pickAndFlashFile, // Gọi hàm chọn file thật
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTerminal() {
    return Container(
      height: 140, color: Colors.black,
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), color: const Color(0xFF1A1A1A),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("> TERMINAL", style: TextStyle(fontSize: 10, color: Colors.grey)),
            InkWell(onTap: () => setState(() => _logText = ""), child: const Text("CLEAR", style: TextStyle(color: Colors.white, fontSize: 10))),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          child: Text(_logText.isEmpty ? "# Ready..." : _logText, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00FF7F), fontSize: 11)),
        ))
      ]),
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
    setState(() { _isScanning = true; _status = "Đang quét..."; });
    for (int i = 0; i <= 100; i+=2) {
      await Future.delayed(const Duration(milliseconds: 20));
      setState(() => _percent = i / 100);
    }
    widget.onLog(">> Running Smart Clean...");
    // Chạy cả lệnh root và non-root để chắc chắn dọn được
    widget.onRun("pm trim-caches 999G"); 
    widget.onRun("am kill-all"); // Thử kill app ngầm (cần quyền cao)
    setState(() { _isScanning = false; _status = "Hoàn tất!"; _percent = 1.0; });
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularPercentIndicator(
        radius: 70.0, lineWidth: 10.0, percent: _percent,
        center: IconButton(
          icon: Icon(_isScanning ? Icons.hourglass_top : Icons.rocket_launch, size: 40, color: Colors.white),
          onPressed: _isScanning ? null : _startScan,
        ),
        progressColor: const Color(0xFF00FF7F), backgroundColor: const Color(0xFF222222),
      ),
      const SizedBox(height: 20),
      Text(_status, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    ]));
  }
}
