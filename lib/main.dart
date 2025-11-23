import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUIOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0D1117),
  ));
  runApp(const AdbMasterApp());
}

// ================= CẤU TRÚC DỮ LIỆU =================
class TweakCommand {
  final String name;
  final String description;
  final String command;
  final String category;
  final bool requiresRoot;
  final bool isSafe;
  final bool isCustomInput;

  const TweakCommand({
    required this.name,
    required this.description,
    required this.command,
    required this.category,
    this.requiresRoot = false,
    this.isSafe = true,
    this.isCustomInput = false,
  });
}

// ================= DANH SÁCH TWEAK =================
final List<TweakCommand> masterTweaks = [
  TweakCommand(
    name: "SAMSUNG AUTO OPTIMIZER",
    description: "Tự động tối ưu độ phân giải cho máy Samsung.",
    category: "Display",
    command: "samsung_auto_detect",
    isCustomInput: true,
    isSafe: true,
  ),
  TweakCommand(
    name: "Khôi phục Màn hình Gốc",
    description: "Reset độ phân giải về mặc định (Cứu máy).",
    category: "Display",
    command: "wm size reset; wm density reset",
    isSafe: true,
  ),
  TweakCommand(
    name: "Kích hoạt Doze Mode",
    description: "Bắt buộc máy ngủ sâu để tiết kiệm pin.",
    category: "Battery",
    command: "dumpsys deviceidle force-idle",
  ),
  TweakCommand(
    name: "FSTRIM (Tăng tốc)",
    description: "Dọn dẹp bộ nhớ flash giúp máy mượt hơn.",
    category: "Performance",
    command: "sm f-trim",
  ),
  TweakCommand(
    name: "Reboot",
    description: "Khởi động lại thiết bị.",
    category: "System",
    command: "reboot",
  ),
];

// ================= GIAO DIỆN CHÍNH =================
class AdbMasterApp extends StatelessWidget {
  const AdbMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Master GitHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF00E676),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          surface: Color(0xFF161B22),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ScrollController _scrollController = ScrollController();
  String _terminalOutput = "ADB Master Initialized...\nWaiting for command...\n";
  bool _isRooted = false;
  String _deviceModel = "Unknown";

  @override
  void initState() {
    super.initState();
    _checkRoot();
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _deviceModel = androidInfo.model;
        });
        _terminalOutput += "> Device detected: $_deviceModel\n";
      }
    } catch (e) {
      // Ignore error on non-android platforms
    }
  }

  Future<void> _checkRoot() async {
    try {
      final result = await Process.run('su', ['-c', 'id']);
      setState(() {
        _isRooted = result.exitCode == 0;
        _terminalOutput += _isRooted ? "> Root Access: YES\n" : "> Root Access: NO (User Mode)\n";
      });
    } catch (e) {
      setState(() => _isRooted = false);
    }
  }

  Future<void> _executeCommand(String command) async {
    // Sửa lỗi ký tự $ bằng cách escape (\$)
    setState(() => _terminalOutput += "\n\$ ${_isRooted ? 'su' : 'sh'} -c '$command'\n");
    
    try {
      ProcessResult result;
      if (_isRooted) {
        result = await Process.run('su', ['-c', command]);
      } else {
        result = await Process.run('sh', ['-c', command]);
      }

      String output = result.stdout.toString() + result.stderr.toString();
      if (output.trim().isEmpty) output = "Done (No Output).";

      setState(() => _terminalOutput += "$output\n");
    } catch (e) {
      setState(() => _terminalOutput += "Error: $e\n");
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADB MASTER", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 7,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: masterTweaks.length,
              itemBuilder: (context, index) {
                final tweak = masterTweaks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.code, color: Colors.orange),
                    title: Text(tweak.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(tweak.description, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    trailing: const Icon(Icons.play_arrow, color: Color(0xFF00E676)),
                    onTap: () => _executeCommand(tweak.command),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          Container(
            height: 150,
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text(
                _terminalOutput,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF00E676),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
