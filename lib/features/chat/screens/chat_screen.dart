import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/features/auth/services/auth_service.dart';

class ChatMessage {
  final String role; // 'user' | 'model'
  final String text;
  final DateTime at;

  ChatMessage({required this.role, required this.text, DateTime? at})
    : at = at ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _compactHeader = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onChatScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final history = <Map<String, String>>[];
      for (var i = 0; i < _messages.length - 1; i++) {
        final m = _messages[i];
        history.add({'role': m.role, 'text': m.text});
      }
      final res = await Api.chat.sendMessage(text, history: history);
      final reply = res['reply']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'model', text: reply));
          _sending = false;
        });
        _scrollToEnd();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        final message = e.message.toLowerCase().contains('unauthenticated')
            ? 'تعذّر الوصول للمساعد. تأكد من أن السيرفر يعرّض POST /api/chat/message بدون اشتراط تسجيل الدخول.'
            : e.message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString().split('\n').first)));
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onChatScroll() {
    if (!_scrollController.hasClients) return;
    final compact = _scrollController.offset > 24;
    if (compact != _compactHeader && mounted) {
      setState(() => _compactHeader = compact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: settings.textDirection,
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              _buildChatHeader(context),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: Container(
                    color: RastUi.screenSurface(context),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              Responsive.spacing(context, 24),
                              Responsive.spacing(context, 14),
                              Responsive.spacing(context, 24),
                              Responsive.spacing(context, 14),
                            ),
                            children: [
                              _dayLabel(context),
                              for (final msg in _messages)
                                _messageTile(context, msg),
                              if (_sending) _typingTile(context),
                            ],
                          ),
                        ),
                        _composer(context, isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.fromLTRB(
          Responsive.spacing(context, 20),
          Responsive.spacing(context, _compactHeader ? 8 : 16),
          Responsive.spacing(context, 20),
          Responsive.spacing(context, _compactHeader ? 8 : 18),
        ),
        child: Row(
          children: [
            _roundHeaderButton(
              icon: Icons.more_vert_rounded,
              onTap: () => _showChatMenu(),
            ),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'المساعد الذكي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.fontSize(
                      context,
                      _compactHeader ? 14 : 16,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!_compactHeader) ...[
                  const SizedBox(height: 2),
                  Text(
                    AuthService.isLoggedIn ? 'اونلاين' : 'زائر',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: Responsive.fontSize(context, 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 10),
            if (!_compactHeader)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const CircleAvatar(
                    radius: 21,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: RastUi.purple,
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 0,
                    end: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3ADB76),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: RastUi.cardSurface(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RastUi.softBorder(ctx),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded),
              title: const Text('مسح المحادثة'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _messages.clear());
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward_rounded),
              title: const Text('الانتقال للأعلى'),
              onTap: () {
                Navigator.pop(ctx);
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: const Color(0xFF42364B), size: 24),
        ),
      ),
    );
  }

  Widget _dayLabel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'اليوم',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: RastUi.secondaryText(context),
          fontSize: Responsive.fontSize(context, 13),
        ),
      ),
    );
  }

  Widget _messageTile(BuildContext context, ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width * (isUser ? 0.76 : 0.82),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, 14),
              vertical: Responsive.spacing(context, 12),
            ),
            decoration: BoxDecoration(
              color: isUser ? null : RastUi.subtleFill(context),
              gradient: isUser ? RastUi.headerGradient : null,
              borderRadius: BorderRadius.circular(8),
              border: isUser
                  ? null
                  : Border.all(color: RastUi.softBorder(context)),
            ),
            child: Text(
              msg.text.isEmpty ? '—' : msg.text,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isUser ? Colors.white : RastUi.primaryText(context),
                fontSize: Responsive.fontSize(context, 13),
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              Text(
                _timeLabel(msg.at),
                style: TextStyle(
                  color: RastUi.secondaryText(context),
                  fontSize: Responsive.fontSize(context, 11),
                ),
              ),
              const SizedBox(width: 12),
              if (isUser) ...[
                Text(
                  AuthService.currentUser?.name ?? 'زائر',
                  style: TextStyle(
                    color: RastUi.primaryText(context),
                    fontSize: Responsive.fontSize(context, 11),
                  ),
                ),
                const SizedBox(width: 6),
                const CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_rounded, size: 14),
                ),
              ] else ...[
                Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RastUi.blue.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: RastUi.blue,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'الدعم الصحي',
                  style: TextStyle(
                    color: RastUi.primaryText(context),
                    fontSize: Responsive.fontSize(context, 11),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _typingTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: RastUi.subtleFill(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: RastUi.softBorder(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RastUi.purple,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'جاري الرد...',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  color: RastUi.purple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(BuildContext context, bool isDark) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.spacing(context, 20),
          8,
          Responsive.spacing(context, 20),
          Responsive.spacing(context, 16),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? RastUi.darkPanel : const Color(0xFFF0F0F1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RastUi.headerGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.mic_rounded, color: Colors.white),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'أكتب الرسالة هنا ...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    hintStyle: TextStyle(color: RastUi.secondaryText(context)),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: _sending ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(6),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(Icons.add_rounded, color: RastUi.blue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
