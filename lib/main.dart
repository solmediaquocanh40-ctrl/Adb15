import 'dart:io';
import 'package:flutter/material.dart';
// Đã bỏ import services để tránh lỗi
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ĐÃ XÓA ĐOẠN CODE CHỈNH MÀU THANH TRẠNG THÁI GÂY LỖI
  runApp(const AdbMasterApp());
}

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

final List<TweakCommand> masterTweaks = [
  TweakCommand(
    name: "SAMSUNG AUTO OPTIMIZER",
    description: "Tu dong toi uu do phan giai.",
    category: "Display",
    command: "samsung_auto_detect",
    isCustomInput: true,
    isSafe: true,
  ),
  TweakCommand(
    name: "Khoi phuc Man hinh Goc",
    description: "Reset do phan giai.",
    category: "Display",
    command: "wm size reset; wm density reset",
    isSafe: true,
  ),
  TweakCommand(
    name: "FSTRIM",
    description: "Don dep bo nho.",
    category: "Performance",
    command: "sm f-trim",
  ),
  TweakCommand(
    name: "Reboot",
    description: "Khoi dong lai.",
    category: "System",
    command: "reboot",
  ),
];

class AdbMasterApp extends StatelessWidget {
  const AdbMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Master Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
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
  String _terminalOutput = "Ready...\n";
  bool _isRooted = false;
  String _deviceModel = "Unknown";

  @override
  void initState() {
    super.initState();
    _checkRoot();
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _deviceModel = androidInfo.model;
        });
        _terminalOutput += "> Device: $_deviceModel\n";
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _checkRoot() async {
    try {
      final result = await Process.run('su', ['-c', 'id']);
      setState(() {
        _isRooted = result.exitCode == 0;
        _terminalOutput += _isRooted ? "> Root: YES\n" : "> Root: NO\n";
      });
    } catch (e) {
      setState(() => _isRooted = false);
    }
  }

  Future<void> _executeCommand(String command) async {
    setState(() => _terminalOutput += "\n# $command\n");
    try {
      ProcessResult result;
      if (_isRooted) {
        result = await Process.run('su', ['-c', command]);
      } else {
        result = await Process.run('sh', ['-c', command]);
      }
      String output = result.stdout.toString() + result.stderr.toString();
      if (output.trim().isEmpty) output = "Done.";
      setState(() => _terminalOutput += "$output\n");
    } catch (e) {
      setState(() => _terminalOutput += "Error: $e\n");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ADB MASTER LITE")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: masterTweaks.length,
              itemBuilder: (context, index) {
                final tweak = masterTweaks[index];
                return ListTile(
                  title: Text(tweak.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(tweak.description),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => _executeCommand(tweak.command),
                );
              },
            ),
          ),
          Container(
            height: 150,
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text(_terminalOutput, style: const TextStyle(fontFamily: 'monospace', color: Colors.green)),
            ),
          )
        ],
      ),
    );
  }
}
