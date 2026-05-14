import 'package:flutter/material.dart';
import 'package:syni/src/runtime/runtime.dart';
import 'models/chat_message.dart';

class ChatPage extends StatefulWidget {
  final String modelPath;

  const ChatPage({super.key, required this.modelPath});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final SyniRuntime _runtime = SyniRuntime();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];

  bool _isReady = false;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      await _runtime.initialize();
      await _runtime.loadModel(widget.modelPath);
      setState(() {
        _isReady = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load model: $e';
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_isReady || _isGenerating) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isGenerating = true;
    });
    _controller.clear();
    _scrollToEnd();

    final idx = _messages.length;
    _messages.add(ChatMessage(text: '', isUser: false));

    try {
      final request = SyniRuntimeRequest(
        instruction: text,
        hsi: {
          'coherence': 0.8,
          'focus': 'high',
        },
      );

      final response = await _runtime.run(
        request,
        preset: SyniPreset.chat,
        seed: 0,
      );

      // Parse response and extract message
      String responseText = '';
      try {
        final data = response.data;
        if (data is Map) {
          // Try to extract message from common response formats
          responseText = data['message']?.toString() ?? 
                        data['text']?.toString() ?? 
                        data['response']?.toString() ?? 
                        response.rawJson;
        } else {
          responseText = response.rawJson;
        }
      } catch (e) {
        responseText = response.rawJson;
      }

      setState(() {
        _messages[idx] = ChatMessage(
          text: responseText,
          isUser: false,
          timestamp: _messages[idx].timestamp,
        );
      });
    } catch (e) {
      setState(() {
        _messages[idx] = ChatMessage(
          text: 'Error: $e',
          isUser: false,
        );
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _runtime.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Messages
            Expanded(child: _buildMessageList()),
            // Input
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          const Spacer(),
          Column(
            children: [
              const Text(
                'syni',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isReady
                          ? const Color(0xFF22C55E)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isLoading
                        ? 'loading'
                        : _isGenerating
                            ? 'thinking'
                            : 'ready',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.withValues(alpha: 0.8),
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.4)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'loading model',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'S',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w200,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ask anything',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isLast = index == _messages.length - 1;
        return _MessageBubble(
          message: msg,
          showCursor: isLast && !msg.isUser && _isGenerating,
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'message',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                enabled: _isReady && !_isGenerating,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isReady && !_isGenerating ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isReady && !_isGenerating
                    ? const Color(0xFF6366F1)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_upward,
                size: 20,
                color: _isReady && !_isGenerating
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showCursor;

  const _MessageBubble({
    required this.message,
    this.showCursor = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              ),
              child: const Center(
                child: Text(
                  'S',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF6366F1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  text: message.text,
                  children: showCursor
                      ? [
                          TextSpan(
                            text: ' ▊',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ]
                      : null,
                ),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: isUser ? Colors.white : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 38),
        ],
      ),
    );
  }
}
