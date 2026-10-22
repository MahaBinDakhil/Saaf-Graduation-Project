import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'services/chat_service.dart';
import 'theme/app_colors.dart';
import 'widgets/app_bottom_nav.dart';

class ChatbotScreen extends StatefulWidget {
  final String? chatId;
  final String? diseaseId;
  final double? confidence;

  const ChatbotScreen({
    super.key,
    this.chatId,
    this.diseaseId,
    this.confidence,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _activeChatId;
  Stream<List<ChatMessage>>? _messagesStream;
  String? _error;
  List<ChatMessage> _messages = [];
  bool _isTyping = false;

  // Quick replies shown when the chat is opened from a scan result.
  final List<String> _diseaseSuggestions = [
    'How can I treat this disease?',
    'How did you identify this disease?',
    'How do I stop it from spreading?',
  ];

  // Quick replies shown when the chat is opened from the nav bar (no scan).
  final List<String> _generalSuggestions = [
    'What is Black Scorch?',
    'How do I treat Black Scorch?',
    'How do I keep my date palm healthy?',
  ];

  @override
  void initState() {
    super.initState();
    _setChat(widget.chatId);
    if (_activeChatId == null) _startChat();
  }

  // Keeps one message stream per chat (not a new one on every rebuild).
  void _setChat(String? id) {
    _activeChatId = id;
    _messagesStream = id == null ? null : ChatService.messagesStream(id);
  }

  // Creates a new chat session. Fails after 15 seconds instead of spinning forever.
  void _startChat() {
    setState(() => _error = null);
    ChatService.startChat(
      diseaseId: widget.diseaseId,
      title: widget.diseaseId != null ? 'Scan Question' : 'New Chat',
    ).timeout(const Duration(seconds: 15)).then((id) {
      if (mounted) setState(() => _setChat(id));
    }).catchError((e) {
      debugPrint('startChat failed: $e');
      if (mounted) setState(() => _error = e.toString());
    });
  }

  // Sends a message (typed or from a quick reply) and waits for the bot reply.
  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _activeChatId == null || _isTyping) return;

    _controller.clear();
    setState(() => _isTyping = true);
    _scrollToEnd();

    try {
      await ChatService.send(
        chatId: _activeChatId!,
        history: _messages,
        userText: text,
        diseaseId: widget.diseaseId,
        confidence: widget.confidence,
        language: _isArabic(text) ? 'ar' : 'en',
      ).timeout(const Duration(seconds: 90));
    } catch (e) {
      debugPrint('send failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send the message. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static bool _isArabic(String s) => RegExp(r'[؀-ۿ]').hasMatch(s);

  // =========================================================
  // SMALL PIECES
  // =========================================================

  /// Dark green circle with the Sa'af logo.
  Widget _avatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Transform.translate(
          offset: Offset(size * 0.026, -size * 0.046),
          child: Transform.scale(
            scale: 1.45,
            child: Image.asset('assets/images/logo_light.png',
                fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Icon(icon, color: AppColors.textDark, size: 26),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
      child: Row(
        children: [
          _roundButton(Icons.chevron_left_rounded,
              () => Navigator.maybePop(context)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _avatar(48),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Sa'af Assistant",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34C26B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isTyping ? 'Typing...' : 'Online',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  ),
                ),
              ],
            ),
          ),
          _roundButton(Icons.more_horiz_rounded, _openPreviousChats),
        ],
      ),
    );
  }

  /// Rounded text field with the round send button.
  Widget _inputField({required String hint}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 4, 6, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE1EADF)),
        boxShadow: [
          BoxShadow(
            color: AppColors.healthyGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _send(),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              cursorColor: AppColors.primary,
              style: const TextStyle(fontSize: 16, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(fontSize: 16, color: AppColors.mutedText),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isTyping
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // WELCOME (no messages yet)
  // =========================================================

  Widget _welcome() {
    final suggestions =
        widget.diseaseId != null ? _diseaseSuggestions : _generalSuggestions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  // The logo shrinks on short screens so nothing gets clipped.
                  final logo = (c.maxHeight * 0.36).clamp(90.0, 140.0);
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _glowingLogo(logo),
                          const SizedBox(height: 22),
                          const Text(
                            "Ask Sa'af anything",
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Palm diseases, care tips and treatments',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Suggestion cards (scroll sideways)
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _suggestionCard(suggestions[i], showIcon: i == 0),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: _inputField(hint: 'Message'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowingLogo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6EE),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: 0.40),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      child: ClipOval(
        child: OverflowBox(
          maxWidth: size * 1.23,
          maxHeight: size * 1.23,
          child: Image.asset(
            'assets/images/logo_color.png',
            width: size * 1.23,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _suggestionCard(String text, {required bool showIcon}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _send(text),
        child: Container(
          width: 210,
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDDE8DA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),
              if (showIcon) ...[
                const SizedBox(width: 8),
                const Icon(Icons.auto_awesome_outlined,
                    color: AppColors.healthyGreen, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CONVERSATION
  // =========================================================

  Widget _conversation() {
    return Column(
      children: [
        Expanded(child: _messageList()),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
          child: _inputField(hint: "Ask Sa'af AI..."),
        ),
      ],
    );
  }

  Widget _messageList() {
    final count = _messages.length + (_isTyping ? 1 : 0);

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      itemCount: count,
      itemBuilder: (context, i) {
        // Last item is the typing indicator while waiting for a reply.
        if (i == _messages.length) return _typingBubble();

        final m = _messages[i];
        final day = m.createdAt ?? DateTime.now();
        final prevDay = i == 0
            ? null
            : (_messages[i - 1].createdAt ?? DateTime.now());
        final showDate = prevDay == null || !_sameDay(day, prevDay);

        return Column(
          children: [
            if (showDate) _datePill(day),
            m.isUser ? _userBubble(m.text) : _botBubble(m.text),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _datePill(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Yesterday'
            : '${d.day} ${months[d.month - 1]}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE6E9E3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _userBubble(String text) {
    final rtl = _isArabic(text);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, left: 60),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            text,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _botBubble(String text) {
    final rtl = _isArabic(text);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(38),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                  bottomLeft: Radius.circular(6),
                ),
                border: Border.all(color: const Color(0xFFEDEFEA)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: _FormattedText(text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(38),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEDEFEA)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.healthyGreen,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  "Sa'af is thinking...",
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Shown when the chat session could not be created.
  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFBE7DD),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppColors.diseased, size: 34),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not open the chat',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _startChat,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: const Text('Try again',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PREVIOUS CHATS SHEET ("..." button)
  // =========================================================

  void _openPreviousChats() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.inputBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Previous chats',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      // Start a fresh chat
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChatbotScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded,
                            size: 18, color: AppColors.primary),
                        label: const Text('New chat'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.primary,
                          shape: const StadiumBorder(),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: ChatService.chatsStream(),
                    builder: (ctx, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        );
                      }
                      final chats = snapshot.data!;
                      if (chats.isEmpty) {
                        return const Center(
                          child: Text(
                            'No previous chats yet.',
                            style: TextStyle(color: AppColors.mutedText),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final c = chats[i];
                          final id = c['id'] as String;
                          final disease = (c['diseaseId'] ?? '').toString();
                          final date =
                              (c['lastMessageAt'] as Timestamp?)?.toDate();
                          final selected = id == _activeChatId;

                          return Material(
                            color: selected
                                ? AppColors.softGreen
                                : AppColors.pageBg,
                            borderRadius: BorderRadius.circular(18),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppColors.primary,
                                    size: 20),
                              ),
                              title: Text(
                                (c['title'] ?? 'Chat').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              subtitle: date == null
                                  ? null
                                  : Text(
                                      '${date.day}/${date.month}/${date.year}',
                                      style: const TextStyle(
                                          color: AppColors.mutedText),
                                    ),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.mutedText),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                if (selected) return;
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChatbotScreen(
                                      chatId: id,
                                      diseaseId:
                                          disease.isEmpty ? null : disease,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    Widget body;
    if (_error != null) {
      body = _errorView();
    } else if (_messagesStream == null) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else {
      body = StreamBuilder<List<ChatMessage>>(
        stream: _messagesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load messages:\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          _messages = snapshot.data!;
          if (_messages.isEmpty && !_isTyping) return _welcome();
          return _conversation();
        },
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              Expanded(child: body),
            ],
          ),
        ),
        // The nav bar is hidden while the keyboard is open so it does not
        // take space from the text field.
        bottomNavigationBar: keyboardOpen
            ? null
            : const AppBottomNavigationBar(current: NavTab.chatbot),
      ),
    );
  }
}

// =========================================================
// BOT TEXT FORMATTING
// Turns the bot reply into: headings, numbered steps (lime circles),
// bullet points and **bold** words.
// =========================================================

class _FormattedText extends StatelessWidget {
  const _FormattedText(this.text);
  final String text;

  static const _base = TextStyle(
    color: AppColors.textDark,
    fontSize: 16,
    height: 1.45,
  );

  // Splits "**bold**" parts into bold spans.
  static List<TextSpan> _spans(String s) {
    final spans = <TextSpan>[];
    final reg = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in reg.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return spans;
  }

  Widget _rich(String s, {TextStyle style = _base}) =>
      Text.rich(TextSpan(style: style, children: _spans(s)));

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$');
    final bullet = RegExp(r'^[-*•]\s+(.*)$');
    final heading = RegExp(r'^#{1,6}\s*(.*)$');
    final boldLine = RegExp(r'^\*\*(.+)\*\*:?$');

    for (final raw in text.trim().split('\n')) {
      final line = raw.trim();

      if (line.isEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 8));
        continue;
      }

      final h = heading.firstMatch(line) ?? boldLine.firstMatch(line);
      final n = numbered.firstMatch(line);
      final b = bullet.firstMatch(line);

      if (h != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            h.group(1)!.replaceAll('**', ''),
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ));
      } else if (n != null) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  n.group(1)!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _rich(n.group(2)!)),
            ],
          ),
        ));
      } else if (b != null) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 9, left: 4, right: 4),
                decoration: const BoxDecoration(
                  color: AppColors.healthyGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _rich(b.group(1)!)),
            ],
          ),
        ));
      } else {
        children.add(_rich(line));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}