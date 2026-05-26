// Minimal example for the `syni` package.
//
// Demonstrates the agent layer: loading a persona from bundled spec
// assets, installing the on-device model, and running a single chat
// turn. Strip what you don't need — the same agent API drives both
// local-only and cloud-routed chat.

import 'package:flutter/material.dart';
import 'package:syni/agent.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SyniExampleApp());
}

class SyniExampleApp extends StatelessWidget {
  const SyniExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syni example',
      theme: ThemeData(useMaterial3: true),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SyniAgent _agent = SyniAgent();
  final TextEditingController _controller = TextEditingController(
    text: 'How can I focus better right now?',
  );

  SyniInstallState _state = const SyniNotInstalled();
  String _reply = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _agent.installState.listen((s) => setState(() => _state = s));
  }

  @override
  void dispose() {
    _agent.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() => _busy = true);
    try {
      // Resolve the persona from the bundled spec asset (id matches a
      // file under `assets/personas/prod/`).
      final persona = await SyniSpecPersona.load('focus.coach.v1');
      await _agent.install(
        persona: persona,
        model: SyniModels.qwen25_15bInstructQ4,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_agent.isInstalled) return;
    setState(() {
      _busy = true;
      _reply = '';
    });
    try {
      final response = await _agent.chat(text);
      if (!mounted) return;
      setState(() => _reply = response.displayText);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Syni example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('State: ${_state.runtimeType}'),
            const SizedBox(height: 12),
            if (!_agent.isInstalled)
              ElevatedButton(
                onPressed: _busy ? null : _install,
                child: const Text('Install model'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Message',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy || !_agent.isInstalled ? null : _send,
              child: const Text('Send'),
            ),
            const SizedBox(height: 16),
            if (_reply.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(child: SelectableText(_reply)),
              ),
          ],
        ),
      ),
    );
  }
}
