import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'chat_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SyniApp());
}

class SyniApp extends StatelessWidget {
  const SyniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syni',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1A1A1A),
          onSurface: Color(0xFFE5E5E5),
        ),
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
      ),
      home: const ModelSelectionPage(),
    );
  }
}

class ModelSelectionPage extends StatefulWidget {
  const ModelSelectionPage({super.key});

  @override
  State<ModelSelectionPage> createState() => _ModelSelectionPageState();
}

class _ModelSelectionPageState extends State<ModelSelectionPage>
    with SingleTickerProviderStateMixin {
  String? _modelPath;
  bool _isLoading = true;
  double _copyProgress = 0;
  late AnimationController _pulseController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadModel();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Try common locations
      final commonPaths = [
        '/Users/henok/Documents/synilife/syni-cli/gguf model/google_gemma-3-1b-it-Q4_K_M.gguf',
        '../../syni-cli/gguf model/google_gemma-3-1b-it-Q4_K_M.gguf',
        '../syni-cli/gguf model/google_gemma-3-1b-it-Q4_K_M.gguf',
      ];

      for (final path in commonPaths) {
        if (File(path).existsSync()) {
          setState(() {
            _modelPath = path;
            _isLoading = false;
          });
          return;
        }
      }

      // Try app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${directory.path}/models');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final modelFile =
          File('${modelDir.path}/google_gemma-3-1b-it-Q4_K_M.gguf');

      if (await modelFile.exists()) {
        setState(() {
          _modelPath = modelFile.path;
          _isLoading = false;
        });
        return;
      }

      // No model found
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _modelPath = result.files.single.path;
        _errorMessage = null;
      });
    }
  }

  void _startChat() {
    if (_modelPath == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChatPage(modelPath: _modelPath!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D0D),
              Color(0xFF1A1A2E),
              Color(0xFF0D0D0D),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6366F1).withValues(
                                alpha: 0.3 + _pulseController.value * 0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF6366F1),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'S',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF6366F1),
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Title
                const Text(
                  'syni',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'on-device ai',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 4,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                // Status
                if (_isLoading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ] else if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.withValues(alpha: 0.8),
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_modelPath != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'model ready',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'no model found',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 2,
                    ),
                  ),
                ],
                const Spacer(),
                // Actions
                if (!_isLoading) ...[
                  GestureDetector(
                    onTap: _modelPath != null ? _startChat : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _modelPath != null
                            ? const Color(0xFF6366F1)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'start',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                            color: _modelPath != null
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickModel,
                    child: Text(
                      'select different model',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
